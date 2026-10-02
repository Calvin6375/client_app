package com.truepay.safaritap

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.ContactsContract
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingContactPick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Draw behind system bars (edge-to-edge). Flutter styles icon contrast
        // via SystemUiOverlayStyle; we avoid deprecated Window.setStatusBarColor.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTACT_PICKER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "pick") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingContactPick != null) {
                result.error("busy", "Contact picker is already open", null)
                return@setMethodCallHandler
            }
            pendingContactPick = result
            try {
                startActivityForResult(
                    Intent(Intent.ACTION_PICK).apply {
                        type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE
                    },
                    PICK_PHONE_REQUEST,
                )
            } catch (_: Exception) {
                pendingContactPick = null
                result.error("unavailable", "Could not open contact picker", null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_PHONE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingContactPick
        pendingContactPick = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data ?: run {
            result.success(null)
            return
        }
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER,
        )
        contentResolver.query(uri, projection, null, null, null).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) {
                result.success(null)
                return
            }
            val name = cursor.getString(
                cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME),
            )
            val number = cursor.getString(
                cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER),
            )
            val normalizedIndex =
                cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER)
            val normalized =
                if (normalizedIndex >= 0) cursor.getString(normalizedIndex) else null
            val phone = normalized?.takeIf { it.isNotBlank() } ?: number
            result.success(
                hashMapOf(
                    "name" to name,
                    "phone" to phone,
                ),
            )
        }
    }

    companion object {
        private const val CONTACT_PICKER_CHANNEL = "com.truepay.safaritap/contact_picker"
        private const val PICK_PHONE_REQUEST = 0xC07A
    }
}
