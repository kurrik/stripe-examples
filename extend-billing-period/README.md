# Extend billing period

[This example](./run.sh) extends a billing period by an arbitrary number of
days by putting the subscription into a trialing state.

To do this, it updates a Subscription with `trial_end` set to the desired
end date and passes `proration_behavior=none`.  This stops the current period
but does not issue a credit for unused time.  Then it creates a new trialing
period until the desired end date.  When the trial finishes, the subscription
will bill as normal (in this example, monthly for $9.99 USD) using the trial
end date as the new subscription anchor date.

A side effect of this approach is that the subscription will have a `status`
of `trialing` until the extended period is over.

**Warning**: If this is run multiple times on the same subscription, or if
applied to an existing trialing subcsription, `trial_start` will not be
updated.  You will need to keep track of actual trialing time ranges if it's
important to understand granular trialing periods.

## Running
No prior setup needed, just pass your key to the sample with:

```
 STRIPE_TEST_KEY=... ./run.sh
```

Example was run with API version `2020-08-27`.

## Output
```
Created a Price with ID price_1Hp1XHK3EYQFZMajbtX6HLnM
Created a Customer with ID cus_IPrFXydBoiEfHw
Created a Subscription with ID sub_IPrFVX96dVlzZN
  Start date:                2020-11-18 17:02:07
  Billing cycle anchor date: 2020-11-18 17:02:07
  Current period start date: 2020-11-18 17:02:07
  Current period end date:   2020-12-18 17:02:07
Press any key to continue . . .
Updated Subscription with ID to trial end of 2020-12-28 17:02:07
  Start date:                2020-11-18 17:02:07
  Billing cycle anchor date: 2020-12-28 17:02:07
  Current period start date: 2020-11-18 17:02:14
  Current period end date:   2020-12-28 17:02:07
```

Interesting files:

| File                                                                         | Description                                                                        |
|------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| [01-initial-subscription-invoice.pdf](./01-initial-subscription-invoice.pdf) | PDF of the first invoice issued when the subscription is created.                  |
| [01-initial-subscription.json](./01-initial-subscription.json)               | JSON response from the subscription creation call.                                 |
| [02-updated-subscription-invoice.pdf](./02-updated-subscription-invoice.pdf) | PDF of the second invoice issued when the update call completes.                   |
| [02-updated-subscription.json](./02-updated-subscription.json)               | JSON response from the subscription update call.                                   |
| [03-upcoming-invoice.json](./03-upcoming-invoice.json)                       | JSON response from calling the upcoming invoice endpoint after the update is made. |
