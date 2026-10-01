package com.example.exchange

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context

class ZaadAccessibilityService : AccessibilityService() {

    private var isWorking = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || isWorking) return

        val source = rootInActiveWindow ?: event.source ?: return
        
        if (isPinWindow(source)) {
            isWorking = true
            
            Handler(Looper.getMainLooper()).postDelayed({
                val currentRoot = rootInActiveWindow
                if (currentRoot != null) {
                    fillPinAndSend(currentRoot)
                    currentRoot.recycle()
                }
            }, 400)
        }
    }

    private fun isPinWindow(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        
        if (text.contains("pin") || text.contains("fadlan geli") || text.contains("ma hubtaa")) {
            return true
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (isPinWindow(child)) {
                child.recycle()
                return true
            }
            child.recycle()
        }
        return false
    }

    private fun fillPinAndSend(rootNode: AccessibilityNodeInfo) {
        val editTextNode = findPinInputNode(rootNode)
        
        if (editTextNode != null) {
            // 1. Diiradda saar oo guji sanduuqa qoraalka
            editTextNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            editTextNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)

            try {
                val pinValue = "2233" // Binka Zaadka

                // 2. Ku shub binka adigoo adeegsanaya Clipboard Paste (Habka ugu xooggan ee aan khaladaadka keenayn)
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = ClipData.newPlainText("PIN", pinValue)
                clipboard.setPrimaryClip(clip)
                
                editTextNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                
                Log.d("ZaadAccessibility", "PIN-ka waxaa lagu shubay Paste si guul leh.")
            } catch (e: Exception) {
                Log.e("ZaadAccessibility", "Khalad gelinta PIN-ka: ${e.message}")
            }
            
            // 3. Sug 800 milliseconds kadibna riix Send
            Handler(Looper.getMainLooper()).postDelayed({
                val freshRoot = rootInActiveWindow
                if (freshRoot != null) {
                    val clicked = clickSendButton(freshRoot)
                    if (!clicked) {
                        clickRightDialogButton(freshRoot)
                    }
                    freshRoot.recycle()
                }
                
                // Dib u fur adeegga 10 ilbiriqsi kadib
                Handler(Looper.getMainLooper()).postDelayed({
                    isWorking = false
                }, 10000)
                
            }, 800)
            
        } else {
            isWorking = false
        }
    }

    private fun findPinInputNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val className = node.className?.toString() ?: ""
        
        if (className.contains("EditText") || node.isEditable) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findPinInputNode(child)
            if (found != null) {
                return found
            }
            child.recycle()
        }
        return null
    }

    private fun clickSendButton(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""

        if (node.isClickable && (text.contains("send") || text.contains("dir") || text.contains("ok") || desc.contains("send"))) {
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            return true
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (clickSendButton(child)) {
                child.recycle()
                return true
            }
            child.recycle()
        }
        return false
    }

    private fun clickRightDialogButton(node: AccessibilityNodeInfo): Boolean {
        val className = node.className?.toString() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""
        
        if (node.isClickable && className.contains("Button") && !text.contains("cancel") && !text.contains("ka tago")) {
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            return true
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (clickRightDialogButton(child)) {
                child.recycle()
                return true
            }
            child.recycle()
        }
        return false
    }

    override fun onInterrupt() {
        isWorking = false
        Log.d("ZaadAccessibility", "Accessibility Interrupted")
    }
}