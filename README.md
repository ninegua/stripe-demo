# Canister accepting Stripe payment

[Stripe](https://stripe.com) is a payment processing gateway that enables businesses to accept online payments by credit cards and other means.
If you are a merchant already registered with Stripe, a simple way to integrate Stripe's service into your own website is to setup a [Payment Link](https://stripe.com/en-us/payments/payment-links).
Users clicking the payment link will be redirected to Stripe's website to make a payment before being redirected back to your website.

There are two ways to know if a successful payment is made:

1. Setup a [webhook](https://docs.stripe.com/webhooks) that allows Stripe to post a JSON message to your website, and it will tell you the payment amount and other details.

2. Find out the `checkout_session_id` (or `payment_intent_id`) associated with the user's payment, and call Stripe's web service API to lookup payment details.

method 1 requires you to verify the a signature (embedded in the `stripe-signature` header) of the message using a master secret key,
while method 2 only requires a read-only key of limited scope.

They both have downsides:

1. Method 1 is less secure because the master key is stored in a canister's heap memory, and if anyone manages to obtain this key, they can forge `stripe-signature` for fake payments.

2. Method 2 requires canisters making HTTPs outcalls to an [idempotent proxy](https://github.com/ldclabs/idempotent-proxy) that supports IPv6, because api.stripe.com only supports IPv4.

## Method 1: Stripe notifies canister via a webhook

## Method 2: Canister pulls Stripe with a checkout session id

For local deployment:

1. Make sure dfx has been started locally. If not run 
  ```
  dfx start --background
  ```
2. Prepare depdenency packages
  ```
  npm install
  export PATH=$PWD/node_modules/.bin:$PATH
  mops install
  ```
3. Create an account with Stripe if not already registered.
4. Create a testing payment link in Stripe.
   In "After payment" tab, choose "Don't show confirmation page", and fill in a redirection link
   `http://localhost:8080/?check_out_session_id={CHECKOUT_SESSION_ID}`
5. Create a restricted key in Stripe that has read access to "Checkout Sessions".
6. Deploy the backend canister with init argument (fill in the key created in the step above):
  ```
  dfx deploy stripe_backend --argument '(record { api_host = "api.stripe.com"; api_key = "..." })
  ```
7. Use webpack dev server to run frontend
  ```
  npm run dev
  ```
8. Visit frontend URL http://localhost:8080/ in a browser.

Basic workflow is:

1. User clicks the pay button, a random `client_reference_id` is generated, and user is redirected to the Stripe page with the this id.
2. User finishes payment on Stripe's page.
3. Stripe redirects user back to localhost with a `checkout_session_id`.
4. Frontend calls backend canister via a HTTP endpoint and pass it the `checkout_session_id`.
5. Backend upgrades the query call to upgrade call, and makes a HTTPs outcall to api.stripe.com to fetch data.
6. Frontend keeps polling backend until backend gets data from stripe and returns it to frontend.
