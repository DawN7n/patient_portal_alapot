# Optional Cloud Functions

Patient registration and existing walk-in account linking do not require Cloud Functions. They use Firebase Authentication's built-in email-verification link and Firestore directly.

The active `index.js` contains only the optional automatic-receipt trigger for Patient Portal appointments. The previous Resend six-digit OTP and server-side registration endpoints have been removed from the active entry point. Do not configure Resend secrets or deploy OTP functions for the current registration flow.

Cloud Functions deployment requires an eligible billing plan. The automatic-receipt trigger is optional and is not required to create accounts or approve patient links. On the current Spark plan, do not attempt to deploy it.
