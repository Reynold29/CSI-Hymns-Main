package com.reyzie.hymns

import io.flutter.embedding.android.FlutterActivity
import android.os.Build
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private var backCallback: OnBackInvokedCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 34) {
            backCallback = OnBackInvokedCallback {
                finish()
            }
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT, backCallback!!
            )
        }
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= 34 && backCallback != null) {
            onBackInvokedDispatcher.unregisterOnBackInvokedCallback(backCallback!!)
        }
        super.onDestroy()
    }
}

