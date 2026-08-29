package com.truepay.safaritap

import android.os.Bundle
import androidx.activity.EdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Backward-compatible edge-to-edge on Android 14 and below. Android 15+
        // already enforces this for apps targeting SDK 35+.
        EdgeToEdge.enable(this)
        super.onCreate(savedInstanceState)
        // FlutterFragmentActivity still tints the status bar with the deprecated
        // Window.setStatusBarColor API. Re-apply edge-to-edge afterward.
        EdgeToEdge.enable(this)
    }
}
