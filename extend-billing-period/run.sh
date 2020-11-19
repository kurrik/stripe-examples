#!/usr/bin/env bash

# Run with: STRIPE_TEST_KEY=... ./run.sh
# set -o xtrace

# Helper method: Pauses execution until keypress.
function pause {
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

# Helper method: Pulls the field specified by $2 out of the raw JSON passed in
# $1 and converts to a date.
function get_date {
  RAW=$1
  FIELD=$2
  echo ${RAW} | jq --raw-output ${FIELD} | xargs -I{} date -r {} "+%Y-%m-%d %H:%M:%S"
}

# Helper method: Pulls the field specified by $2 out of the raw JSON passed in
# $1 and curls it to save output to $3.
function save_pdf {
  RAW=$1
  FIELD=$2
  OUTPUT=$3
  URL=$(echo ${RAW} | jq --raw-output ${FIELD})
  curl --silent --location $URL > $OUTPUT
}

### Script ###

# Setup: Create a standard monthly price and associated product.
# (You may also omit `product_data` and refernce an existing Product by ID in
# the `product` field.
PRICE_ID=$(curl --silent https://api.stripe.com/v1/prices \
  -u ${STRIPE_TEST_KEY}: \
  -d product_data[name]="Standard Monthly Billing" \
  -d recurring[interval]=month \
  -d currency=USD \
  -d unit_amount=999 |
  jq --raw-output '.id')

echo "Created a Price with ID ${PRICE_ID}"

# Setup: Create a customer with a valid card.
CUSTOMER_ID=$(curl --silent https://api.stripe.com/v1/customers \
  -u ${STRIPE_TEST_KEY}: \
  -d source=tok_visa \
  -d description="Customer ${RANDOM}" \
  -d email=test@example.com | \
  jq --raw-output '.id')

echo "Created a Customer with ID ${CUSTOMER_ID}"

# Setup: Subscribe the Customer to the Price.

SUBSCRIPTION_RESPONSE=$(curl --silent https://api.stripe.com/v1/subscriptions \
  -u ${STRIPE_TEST_KEY}: \
  -d customer=${CUSTOMER_ID} \
  -d items[0][price]=${PRICE_ID} \
  -d expand[]=latest_invoice | \
  tee 01-initial-subscription.json)

SUB_ID=$(echo ${SUBSCRIPTION_RESPONSE} | jq --raw-output '.id')
START_DATE=$(get_date "${SUBSCRIPTION_RESPONSE}" '.start_date')
BILLING_CYCLE_ANCHOR_DATE=$(get_date "${SUBSCRIPTION_RESPONSE}" '.billing_cycle_anchor')
CURRENT_PERIOD_START_DATE=$(get_date "${SUBSCRIPTION_RESPONSE}" '.current_period_start')
CURRENT_PERIOD_END_DATE=$(get_date "${SUBSCRIPTION_RESPONSE}" '.current_period_end')

echo "Created a Subscription with ID ${SUB_ID}"
echo "  Start date:                ${START_DATE}"
echo "  Billing cycle anchor date: ${BILLING_CYCLE_ANCHOR_DATE}"
echo "  Current period start date: ${CURRENT_PERIOD_START_DATE}"
echo "  Current period end date:   ${CURRENT_PERIOD_END_DATE}"

save_pdf "${SUBSCRIPTION_RESPONSE}" '.latest_invoice.invoice_pdf' '01-initial-subscription-invoice.pdf'

# Pause to allow checking dashboard, etc.
pause

# Add (arbitrarily) 10 days to the end of the billing period."
EXTEND_BY_DAYS=10
ADJUSTED_END_DATE_UNIX=$(date -j -v "+${EXTEND_BY_DAYS}d" -f "%Y-%m-%d %H:%M:%S" "${CURRENT_PERIOD_END_DATE}" "+%s")
ADJUSTED_END_DATE=$(date -r ${ADJUSTED_END_DATE_UNIX} "+%Y-%m-%d %H:%M:%S")

# Update the subscription to set a trial end date.  Set proration_behavior=none
# so that no refund credits are added.  This will issue a $0 invoice and create
# a new billing period starting now and extending to the supplied trial end
# date.  This will put the subscription into a "trialing" state.
UPDATE_RESPONSE=$(curl --silent https://api.stripe.com/v1/subscriptions/${SUB_ID} \
  -u ${STRIPE_TEST_KEY}: \
  -d trial_end=${ADJUSTED_END_DATE_UNIX} \
  -d proration_behavior=none \
  -d expand[]=latest_invoice | \
  tee 02-updated-subscription.json)

UPDATED_START_DATE=$(get_date "${UPDATE_RESPONSE}" '.start_date')
UPDATED_BILLING_CYCLE_ANCHOR_DATE=$(get_date "${UPDATE_RESPONSE}" '.billing_cycle_anchor')
UPDATED_CURRENT_PERIOD_START_DATE=$(get_date "${UPDATE_RESPONSE}" '.current_period_start')
UPDATED_CURRENT_PERIOD_END_DATE=$(get_date "${UPDATE_RESPONSE}" '.current_period_end')

# Note that the period does change, so the start date will be anchored to the
# date of the update call.
echo "Updated Subscription with ID to trial end of ${ADJUSTED_END_DATE}"
echo "  Start date:                ${UPDATED_START_DATE}"
echo "  Billing cycle anchor date: ${UPDATED_BILLING_CYCLE_ANCHOR_DATE}"
echo "  Current period start date: ${UPDATED_CURRENT_PERIOD_START_DATE}"
echo "  Current period end date:   ${UPDATED_CURRENT_PERIOD_END_DATE}"

save_pdf "${UPDATE_RESPONSE}" '.latest_invoice.invoice_pdf' '02-updated-subscription-invoice.pdf'

# The upcoming invoice shows the next invoice which will be sent.
# The invoice will be sent at $ADJUSTED_END_DATE for the full amount of the Price.
# Future invoices will be anchored to that date.
UPCOMING_INVOICE=$(curl --silent https://api.stripe.com/v1/invoices/upcoming?subscription=${SUB_ID} \
  -u ${STRIPE_TEST_KEY}: | \
  tee 03-upcoming-invoice.json)
