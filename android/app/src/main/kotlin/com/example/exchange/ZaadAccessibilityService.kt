package com.example.exchange

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.net.Uri

class ZaadAccessibilityService : AccessibilityService() {

    private var balanceCheckedAndConfirmed = false
    private var lastHandledText = ""
    private var isBusy = false
    private var isManualRun = false
    private var firstTransferDone = false
    private var secondTransferDone = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        val rootNode = rootInActiveWindow ?: return
        val fullScreenText = extractAllText(rootNode).lowercase()

        if (fullScreenText.isEmpty()) return

        Log.d("ZaadAccessibility", "Screen Text: $fullScreenText")

        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val isCheckBalanceOn = prefs.getBoolean("flutter.check_balance_on", false)
        val isAutoTransferOn = prefs.getBoolean("flutter.auto_transfer_on", true) || prefs.getBoolean("flutter.auto_transfer", true)
        val isManualCheckTriggered = prefs.getBoolean("flutter.manual_check", false)
        val type = prefs.getString("flutter.type", "") ?: ""

        if (isManualCheckTriggered) {
            isManualRun = true
            prefs.edit().putBoolean("flutter.manual_check", false).apply()
        }

        // HADDII CHECK BALANCE IYO AUTO TRANSFER DHOOBADA OFF YIHIIN, HA SHAQEYN
        if (!isCheckBalanceOn && !isAutoTransferOn && !isManualRun && !firstTransferDone) {
            return
        }

        // MARKA CHECK BALANCE UU OFF YAHAY: HADDII ZAAD TRANSFER-KII 2AAD DHAMMAADO, SI BUUXDA U ISTAAG
        if (!isCheckBalanceOn && secondTransferDone && !type.contains("SALAAM BANK", ignoreCase = true)) {
            return
        }

        if (fullScreenText == lastHandledText && 
            !fullScreenText.contains("are you sure") && 
            !fullScreenText.contains("confirm") && 
            !fullScreenText.contains("ma hubtaa")) {
            return
        }

        // 1. QABASHADA ERROOYINKA USSD-KA IYO POP-UP-KA (SIDA: INSUFFICIENT BALANCE, INVALID AMOUNT, ERROR)
        if (fullScreenText.contains("insufficient balance") || 
            fullScreenText.contains("invalid amount") || 
            fullScreenText.contains("invalid menu option") || 
            fullScreenText.contains("invalid option") || 
            fullScreenText.contains("internal service error") || 
            fullScreenText.contains("please try again") || 
            fullScreenText.contains("connection problem") || 
            fullScreenText.contains("invalid mmi code") || 
            fullScreenText.contains("error") || 
            fullScreenText.contains("failed") || 
            fullScreenText.contains("session") || 
            fullScreenText.contains("canceled") || 
            fullScreenText.contains("cancelled")) {
            
            lastHandledText = fullScreenText
            Handler(Looper.getMainLooper()).postDelayed({
                clickSendOrOkButton(rootNode) // Taabo OK
                Handler(Looper.getMainLooper()).postDelayed({
                    isBusy = false
                    balanceCheckedAndConfirmed = false
                    
                    // Haddii Check Balance uu ON yahay, ha istaagin ee dib u bilow shaqada (*882#)
                    if (isCheckBalanceOn || isManualRun) {
                        triggerUssd("*882#")
                    }
                }, 200)
            }, 60)
            return
        }

        if (isBusy) return

        // 2. GELINTA PIN-KA ZAAD-KA
        val zaadPin = prefs.getString("flutter.zaadPin", "") ?: ""
        if (fullScreenText.contains("fadlan geli pin") || 
            fullScreenText.contains("fadlan gali pin") || 
            fullScreenText.contains("enter your pin") || 
            fullScreenText.contains("pin-kaaga")) {
            if (zaadPin.isNotEmpty()) {
                isBusy = true
                lastHandledText = fullScreenText
                executeFastInput(zaadPin)
                return
            }
        }

        // 3. STEP 1 IYO STEP 2: AKHRINTA HADHAAGA SHAASHADDA (SI SAX AH OO LACAGTA LIH DHIBICDA USSD LOOGU DHIBO)
        if (fullScreenText.contains("hadhaageedu waa") || fullScreenText.contains("balance") || fullScreenText.contains("hadhaaga") || fullScreenText.contains("hadhaagaaga") || fullScreenText.contains("u dhiibtay") || fullScreenText.contains("guul")) {
            
            val allMatches = Regex("""\$(\d+(\.\d+)?)""").findAll(fullScreenText).toList()
            val matchResult = if (allMatches.size > 1) {
                allMatches.last()
            } else if (allMatches.size == 1) {
                allMatches.first()
            } else {
                null
            }

            if (matchResult != null) {
                val amountValue = matchResult.groupValues[1]
                val amountDouble = amountValue.toDoubleOrNull() ?: 0.0

                if (amountDouble > 0.0 && !balanceCheckedAndConfirmed) {
                    balanceCheckedAndConfirmed = true
                    isBusy = true
                    lastHandledText = fullScreenText

                    if (!firstTransferDone) {
                        // TALLAABADA 1AAD (STEP 1): Dir lacagtii kowaad oo wadata dhibicdeeda (tusaale 23.01)
                        firstTransferDone = true
                        prefs.edit().putString("flutter.pending_amount", amountValue).apply()

                        val ussdCode = if (type.contains("SALAAM BANK", ignoreCase = true)) {
                            "*888#"
                        } else {
                            val phone = prefs.getString("flutter.phone", "") ?: ""
                            "*880*$phone*$amountValue#"
                        }

                        Handler(Looper.getMainLooper()).postDelayed({
                            clickSendOrOkButton(rootInActiveWindow)
                            
                            Handler(Looper.getMainLooper()).postDelayed({
                                triggerUssd(ussdCode)
                                balanceCheckedAndConfirmed = false
                                isBusy = false
                            }, 300)
                        }, 80)
                        return
                    } else if (!secondTransferDone) {
                        // TALLAABADA 2AAD (STEP 2): AKHRINTA HADHAAGA, TAABO OK -> KA DABA DIR
                        if (!isCheckBalanceOn) {
                            secondTransferDone = true
                        }
                        
                        prefs.edit().putString("flutter.pending_amount", amountValue).apply()

                        val ussdCode = if (type.contains("SALAAM BANK", ignoreCase = true)) {
                            "*888#"
                        } else {
                            val phone = prefs.getString("flutter.phone", "") ?: ""
                            "*880*$phone*$amountValue#"
                        }

                        Handler(Looper.getMainLooper()).postDelayed({
                            clickSendOrOkButton(rootInActiveWindow) // Taabo OK
                            
                            Handler(Looper.getMainLooper()).postDelayed({
                                triggerUssd(ussdCode) // Dir lacagtii hadhaaga ahayd
                                balanceCheckedAndConfirmed = false
                                isBusy = false
                            }, 300)
                        }, 80)
                        return
                    }
                }
            }
        }

        // 4. ZAAD TRANSFER CONFIRMATION
        if (!type.contains("SALAAM BANK", ignoreCase = true)) {
            if (fullScreenText.contains("are you sure") || 
                fullScreenText.contains("confirm") || 
                fullScreenText.contains("ma hubtaa") || 
                fullScreenText.contains("ma rabtaa")) {
                isBusy = true
                lastHandledText = fullScreenText
                executeFastInput("1")
                return
            }

            if (fullScreenText.contains("guul") || fullScreenText.contains("u dhiibtay") || fullScreenText.contains("lagu shubay") || fullScreenText.contains("successful")) {
                isBusy = true
                lastHandledText = fullScreenText
                
                Handler(Looper.getMainLooper()).postDelayed({
                    clickSendOrOkButton(rootInActiveWindow)
                    isBusy = false

                    // Haddii Check Balance uu ON yahay, shaqada ha dib uga bilaabo (*882#) oo ha joojin[cite: 14]
                    if (isCheckBalanceOn || !secondTransferDone) {
                        Handler(Looper.getMainLooper()).postDelayed({
                            triggerUssd("*882#")
                        }, 350)
                    } else {
                        isManualRun = false
                    }
                }, 150)
                return
            }
        }

        // 5. AUTOMATION STEPS FOR SALAAM BANK (*888#)
        if (type.contains("SALAAM BANK", ignoreCase = true)) {
            val registerPin = prefs.getString("flutter.registerPin", "") ?: ""
            val amount = prefs.getString("flutter.pending_amount", "") ?: "1"

            if (fullScreenText.contains("zaad services") && (fullScreenText.contains("darasalam bank") || fullScreenText.contains("8."))) {
                isBusy = true
                lastHandledText = fullScreenText
                executeFastInput("8")
                return
            }

            if (fullScreenText.contains("darasalam bank") && (fullScreenText.contains("lacag dhigasho") || fullScreenText.contains("2."))) {
                isBusy = true
                lastHandledText = fullScreenText
                executeFastInput("2")
                return
            }

            if (fullScreenText.contains("fadlan geli lacagta") || fullScreenText.contains("fadlan gali lacagta") || fullScreenText.contains("geli lacagta")) {
                if (amount.isNotEmpty()) {
                    isBusy = true
                    lastHandledText = fullScreenText
                    executeFastInput(amount)
                    return
                }
            }

            if (fullScreenText.contains("fadlan geli macluumaad") || fullScreenText.contains("geli macluumaad")) {
                isBusy = true
                lastHandledText = fullScreenText
                executeFastInput("1")
                return
            }

            if (fullScreenText.contains("sirta ee bangiga") || fullScreenText.contains("numberkaaga sirta") || fullScreenText.contains("pin-ka bangiga")) {
                if (registerPin.isNotEmpty()) {
                    isBusy = true
                    lastHandledText = fullScreenText
                    executeFastInput(registerPin)
                    return
                }
            }

            if (fullScreenText.contains("are you sure") || fullScreenText.contains("confirm this service") || fullScreenText.contains("ma hubtaa")) {
                isBusy = true
                lastHandledText = fullScreenText
                executeFastInput("1")
                return
            }

            if (fullScreenText.contains("guul") || fullScreenText.contains("lagu shubay") || fullScreenText.contains("sucessful")) {
                isBusy = true
                lastHandledText = fullScreenText
                
                Handler(Looper.getMainLooper()).postDelayed({
                    clickSendOrOkButton(rootInActiveWindow)
                    isBusy = false

                    // Haddii Check Balance uu ON yahay, shaqada ha dib uga bilaabo (*882#) oo ha joojin[cite: 14]
                    if (isCheckBalanceOn) {
                        Handler(Looper.getMainLooper()).postDelayed({
                            triggerUssd("*882#")
                        }, 350)
                    } else {
                        isManualRun = false
                    }
                }, 200)
                return
            }
        }
    }

    private fun executeFastInput(textToType: String) {
        Handler(Looper.getMainLooper()).postDelayed({
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                val editable = findEditableNode(rootNode)
                if (editable != null) {
                    editable.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                    val arguments = Bundle().apply {
                        putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, textToType)
                    }
                    editable.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)

                    Handler(Looper.getMainLooper()).postDelayed({
                        clickSendOrOkButton(rootInActiveWindow)
                        isBusy = false
                    }, 80)
                } else {
                    isBusy = false
                }
            } else {
                isBusy = false
            }
        }, 40)
    }

    private fun extractAllText(node: AccessibilityNodeInfo?): String {
        if (node == null) return ""
        val sb = StringBuilder()
        if (node.text != null) {
            sb.append(node.text).append(" ")
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                sb.append(extractAllText(child))
            }
        }
        return sb.toString()
    }

    private fun findEditableNode(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isEditable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val found = findEditableNode(child)
            if (found != null) return found
        }
        return null
    }

    private fun triggerUssd(code: String) {
        val encodedUssd = Uri.encode(code)
        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$encodedUssd")).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("ZaadAccessibility", "Khalad USSD: ${e.message}")
        }
    }

    private fun clickSendOrOkButton(nodeInfo: AccessibilityNodeInfo?) {
        var root = nodeInfo
        while (root?.parent != null) {
            root = root.parent
        }
        root?.let { findAndClickButton(it) } ?: run {
            rootInActiveWindow?.let { findAndClickButton(it) }
        }
    }

    private fun findAndClickButton(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.uppercase() ?: ""
        val contentDesc = node.contentDescription?.toString()?.uppercase() ?: ""

        if (text == "SEND" || text == "OK" || text == "HAA" || text == "DIRO" || contentDesc.contains("SEND") || contentDesc.contains("OK")) {
            if (node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                if (findAndClickButton(child)) {
                    return true
                }
            }
        }
        return false
    }

    override fun onInterrupt() {
        balanceCheckedAndConfirmed = false
        isBusy = false
        isManualRun = false
        firstTransferDone = false
        secondTransferDone = false
        Log.d("ZaadAccessibility", "Service Interrupted")
    }
}