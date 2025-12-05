/**
 * Cloud Functions for TruePay
 *
 * IMPORTANT SECURITY RULES:
 * 1. Always validate Firebase Auth tokens
 * 2. Never trust client input - validate all data
 * 3. All payment creation/updates happen here
 * 4. All wallet updates happen here
 * 5. Client code MUST NOT write to payments or wallet nodes
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.database();

/**
 * Initialize wallet when a new user is created
 * Automatically creates both fiat (USD) and crypto (USDT) wallets with balance 0
 *
 * @param {Object} user - Firebase Auth user object
 * @param {Object} context - Firebase Functions context
 */
exports.initializeWalletOnUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    const userId = user.uid;
    const timestamp = new Date().toISOString();

    // Check if fiat wallet already exists (shouldn't happen, but safety check)
    // NEW PATH: wallet/{userId}/fiat/{currency} (matches backend sync path)
    const fiatWalletRef = db.ref(`wallet/${userId}/fiat/USD`);
    const fiatWalletSnapshot = await fiatWalletRef.once("value");

    // Check if crypto wallet already exists
    const cryptoWalletRef = db.ref(`wallet/${userId}/crypto/USDT`);
    const cryptoWalletSnapshot = await cryptoWalletRef.once("value");

    // Create fiat wallet if it doesn't exist
    if (!fiatWalletSnapshot.exists()) {
      await fiatWalletRef.set({
        balance: 0,
        currency: "USD",
        updatedAt: timestamp,
        createdAt: timestamp,
      });
      console.log(`Fiat wallet initialized for new user ${userId}: 0 USD`);
    } else {
      console.log(`Fiat wallet already exists for user ${userId}, skipping initialization`);
    }

    // Create crypto wallet (USDT) if it doesn't exist
    if (!cryptoWalletSnapshot.exists()) {
      await cryptoWalletRef.set({
        balance: 0,
        currency: "USDT",
        updatedAt: timestamp,
        createdAt: timestamp,
      });
      console.log(`Crypto wallet (USDT) initialized for new user ${userId}: 0 USDT`);
    } else {
      console.log(`Crypto wallet (USDT) already exists for user ${userId}, skipping initialization`);
    }

    console.log(`Wallets initialized for new user ${userId}: 0 USD, 0 USDT`);
  } catch (error) {
    console.error(`Error initializing wallets for user ${user.uid}:`, error);
    // Don't throw - we don't want to block user creation if wallet init fails
    // The wallet can be created later when needed
  }
});

/**
 * Create a new payment
 * Validates user authentication and creates payment in Realtime DB
 *
 * @param {Object} data - Payment data from client
 * @param {Object} context - Firebase Functions context
 * @returns {Object} Payment ID and checkout URL
 */
exports.createPayment = functions.https.onCall(async (data, context) => {
  // Validate authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to create payments",
    );
  }

  const userId = context.auth.uid;
  const userEmail = context.auth.token.email || data.email;

  // Validate input
  if (!data.amount || typeof data.amount !== "number" || data.amount <= 0) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Amount must be a positive number",
    );
  }

  if (!data.currency || typeof data.currency !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Currency is required",
    );
  }

  if (!data.email || typeof data.email !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email is required",
    );
  }

  try {
    // Generate unique payment ID
    const paymentId = `payment_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const timestamp = new Date().toISOString();

    // Payment data
    const paymentData = {
      payment_id: paymentId,
      user_id: userId,
      user_email: userEmail,
      amount: data.amount,
      currency: data.currency.toUpperCase(),
      status: "initiated",
      customer_info: {
        email: data.email,
        first_name: data.firstName || "",
        last_name: data.lastName || "",
      },
      created_at: timestamp,
      updated_at: timestamp,
      payment_method: data.paymentMethod || "intasend",
      platform: "mobile_app",
    };

    // Add optional fields
    if (data.checkoutUrl) paymentData.checkout_url = data.checkoutUrl;
    if (data.intasendCheckoutId) paymentData.intasend_checkout_id = data.intasendCheckoutId;
    if (data.phoneNumber) paymentData.phone_number = data.phoneNumber;
    if (data.metadata) paymentData.metadata = data.metadata;

    // Write to Realtime Database
    await db.ref(`payments/${paymentId}`).set(paymentData);

    // Also create reference in user's payments (for easier querying)
    await db.ref(`users/${userId}/payments/${paymentId}`).set({
      payment_id: paymentId,
      amount: data.amount,
      currency: data.currency.toUpperCase(),
      status: "initiated",
      created_at: timestamp,
    });

    console.log(`Payment created: ${paymentId} for user: ${userId}`);

    return {
      success: true,
      paymentId: paymentId,
      checkoutUrl: data.checkoutUrl || null,
      data: paymentData,
    };
  } catch (error) {
    console.error("Error creating payment:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to create payment",
        error.message,
    );
  }
});

/**
 * Handle payment webhook from IntaSend
 * Updates payment status and wallet balance
 *
 * @param {Object} data - Webhook data
 * @param {Object} context - Firebase Functions context
 * @returns {Object} Success status
 */
exports.handlePaymentWebhook = functions.https.onCall(async (data, context) => {
  // Validate authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
    );
  }

  const userId = context.auth.uid;

  // Validate input
  if (!data.paymentId || typeof data.paymentId !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Payment ID is required",
    );
  }

  if (!data.status || typeof data.status !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Status is required",
    );
  }

  const validStatuses = ["initiated", "link_opened", "completed", "failed"];
  if (!validStatuses.includes(data.status)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        `Status must be one of: ${validStatuses.join(", ")}`,
    );
  }

  try {
    const paymentId = data.paymentId;
    const timestamp = new Date().toISOString();

    // Get current payment data
    const paymentRef = db.ref(`payments/${paymentId}`);
    const paymentSnapshot = await paymentRef.once("value");

    if (!paymentSnapshot.exists()) {
      throw new functions.https.HttpsError(
          "not-found",
          "Payment not found",
      );
    }

    const paymentData = paymentSnapshot.val();

    // Verify payment belongs to authenticated user
    if (paymentData.user_id !== userId) {
      throw new functions.https.HttpsError(
          "permission-denied",
          "Payment does not belong to user",
      );
    }

    // Update payment status
    const updateData = {
      status: data.status,
      updated_at: timestamp,
    };

    if (data.status === "link_opened") {
      updateData.link_opened_at = timestamp;
    } else if (data.status === "completed") {
      updateData.completed_at = timestamp;
      if (data.transactionId) updateData.transaction_id = data.transactionId;
      if (data.webhookData) updateData.payment_details = data.webhookData;
    } else if (data.status === "failed") {
      updateData.failed_at = timestamp;
      if (data.errorReason) updateData.error_reason = data.errorReason;
    }

    await paymentRef.update(updateData);

    // Update user's payment reference
    await db.ref(`users/${userId}/payments/${paymentId}`).update({
      status: data.status,
      updated_at: timestamp,
    });

    // If payment completed, update wallet
    if (data.status === "completed") {
      await updateWalletAfterPayment({
        userId: userId,
        amount: paymentData.amount,
        currency: paymentData.currency,
      });
    }

    console.log(`Payment ${paymentId} updated to status: ${data.status}`);

    return {
      success: true,
      paymentId: paymentId,
      status: data.status,
    };
  } catch (error) {
    console.error("Error handling payment webhook:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to handle payment webhook",
        error.message,
    );
  }
});

/**
 * Update wallet balance after payment completion
 * This is called internally by handlePaymentWebhook
 *
 * @param {Object} params - Wallet update parameters
 */
async function updateWalletAfterPayment(params) {
  const {userId, amount, currency} = params;

  try {
    // NEW PATH: wallet/{userId}/fiat/{currency} (matches backend sync path)
    const currencyCode = (currency || "USD").toUpperCase();
    const walletRef = db.ref(`wallet/${userId}/fiat/${currencyCode}`);
    const walletSnapshot = await walletRef.once("value");

    const timestamp = new Date().toISOString();

    if (walletSnapshot.exists()) {
      // Update existing wallet
      const currentBalance = walletSnapshot.val();
      const newBalance = (currentBalance.balance || 0) + amount;

      await walletRef.update({
        balance: newBalance,
        currency: currencyCode,
        updatedAt: timestamp,
      });

      console.log(`Wallet updated for user ${userId}: ${newBalance} ${currencyCode}`);
    } else {
      // Create new wallet
      await walletRef.set({
        balance: amount,
        currency: currencyCode,
        updatedAt: timestamp,
        createdAt: timestamp,
      });

      console.log(`Wallet created for user ${userId}: ${amount} ${currencyCode}`);
    }
  } catch (error) {
    console.error("Error updating wallet:", error);
    throw error;
  }
}

/**
 * Public function to update wallet (for testing/admin use)
 * NOTE: In production, this should have additional security checks
 */
exports.updateWalletAfterPayment = functions.https.onCall(async (data, context) => {
  // Validate authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
    );
  }

  const userId = context.auth.uid;

  // Validate input
  if (!data.amount || typeof data.amount !== "number") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Amount is required",
    );
  }

  if (!data.currency || typeof data.currency !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Currency is required",
    );
  }

  try {
    await updateWalletAfterPayment({
      userId: userId,
      amount: data.amount,
      currency: data.currency,
    });

    return {
      success: true,
      message: "Wallet updated successfully",
    };
  } catch (error) {
    console.error("Error updating wallet:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to update wallet",
        error.message,
    );
  }
});

/**
 * Initialize crypto wallet for existing users
 * Creates USDT wallet if it doesn't exist
 * Can be called by authenticated users to initialize their crypto wallet
 *
 * @param {Object} data - Request data (optional currency, defaults to USDT)
 * @param {Object} context - Firebase Functions context
 * @returns {Object} Success status
 */
exports.initializeCryptoWallet = functions.https.onCall(async (data, context) => {
  // Validate authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
    );
  }

  const userId = context.auth.uid;
  const currencyCode = (data.currency || "USDT").toUpperCase();
  const timestamp = new Date().toISOString();

  try {
    // Check if crypto wallet already exists
    const cryptoWalletRef = db.ref(`wallet/${userId}/crypto/${currencyCode}`);
    const cryptoWalletSnapshot = await cryptoWalletRef.once("value");

    if (cryptoWalletSnapshot.exists()) {
      return {
        success: true,
        message: `Crypto wallet (${currencyCode}) already exists`,
        alreadyExists: true,
      };
    }

    // Create crypto wallet with default balance of 0
    await cryptoWalletRef.set({
      balance: 0,
      currency: currencyCode,
      updatedAt: timestamp,
      createdAt: timestamp,
    });

    console.log(`Crypto wallet (${currencyCode}) initialized for user ${userId}: 0 ${currencyCode}`);

    return {
      success: true,
      message: `Crypto wallet (${currencyCode}) initialized successfully`,
      alreadyExists: false,
    };
  } catch (error) {
    console.error(`Error initializing crypto wallet for user ${userId}:`, error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to initialize crypto wallet",
        error.message,
    );
  }
});

