# Canister accepting Stripe payment

[Stripe](https://stripe.com) is a payment processing gateway that enables businesses to accept online payments by credit cards and other means.
If you are a merchant already registered with Stripe, a simple way to integrate Stripe's service into your own website is to setup a [Payment Link](https://stripe.com/en-us/payments/payment-links).
Users clicking the payment link will be redirected to Stripe's website to make a payment before being redirected back to your website.

There are two ways to know if a successful payment is made:

1. Setup a [webhook](https://docs.stripe.com/webhooks) that allows Stripe to post a JSON message to your website, and it will tell you the payment amount and other details.

2. Find out the `checkout_session_id` (or `payment_intent_id`) associated with the user's payment, and call Stripe's web service API to lookup payment details.

method 1 requires you to verify the a signature (embedded in the `stripe-signature` header) of the message using a master secret key,
while method 2 only requires a read-only key of limited scope.

The canister code in this repository demostrates both methods, but they both have downsides:

1. Method 1 is less secure because the master key is stored in a canister's heap memory, and if anyone manages to obtain this key, they can forge `stripe-signature` for fake payments.

2. Method 2 requires canisters making HTTPs outcalls to an [idempotent proxy](https://github.com/ldclabs/idempotent-proxy) that supports IPv6, because api.stripe.com only supports IPv4.

## Method 1: Stripe notifies canister via a webhook

## Method 2: Canister pulls Stripe with a checkout session id

