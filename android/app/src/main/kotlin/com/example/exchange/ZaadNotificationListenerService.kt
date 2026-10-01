package com.example.exchange

import android.app.Notification
import android.content.Intent
import android.net.Uri
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class ZaadNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val fullContent = "$title $text".lowercase()

        Log.d("ZaadListener", "Notification helay: $fullContent")

        // Waxaan hubineynaa in ay ku jirto "zaad services" iyo "ka heshay" (sida ku cad sawirka)
        if (fullContent.contains("zaad services") && fullContent.contains("waxaad") && fullContent.contains("ka") && fullContent.contains("heshay")) {
            val amount = extractAmount(fullContent)
            if (amount != null && amount.isNotEmpty()) {
                Log.d("ZaadListener", "Lacagtii la helay: $amount - Bilaabaya USSD...")
                
                // Akhrinta xogta diiwaangelinta ee laga keenay app-ka
                val prefs = getSharedPreferences("RegistrationPrefs", MODE_PRIVATE)
                val type = prefs.getString("type", "ZAAD") ?: "ZAAD"
                
                val ussdCode: String
                
                if (type == "SALAAM BANK") {
                    val zaadPin = prefs.getString("zaadPin", "") ?: ""
                    val registerPin = prefs.getString("registerPin", "") ?: ""
                    
                    // Tillaabooyinka Salaam Bank:
                    // 1. *800#
                    // 2. binka zaadka ($zaadPin)
                    // 3. dooro 5 (darasalam bank)
                    // 4. dooro 2 (lacag dhigasho)
                    // 5. lacagta soodhacday amount keeda ($amount)
                    // 6. gali number 1
                    // 7. geli register binka ee accountka ($registerPin)
                    // 8. dooro number 1
                    ussdCode = "*800*$zaadPin*5*2*$amount*1*$registerPin*1#"
                } else {
                    // Koodkiiagii asalka ahaa ee ZAAD
                    ussdCode = "*880*0634187078*$amount#"
                }

                val encodedUssd = Uri.encode(ussdCode)
                
                val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$encodedUssd")).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                
                try {
                    startActivity(intent)
                } catch (e: Exception) {
                    Log.e("ZaadListener", "Khalad ka dhacay bilaabista USSD: ${e.message}")
                }
            }
        }
    }

    private fun extractAmount(text: String): String? {
        // Waxay ka soo saaraysaa lacagta sida $100 ee ku jirta fariinta
        val regex = Regex("""\$([0-9]+(?:\.[0-9]+)?)""")
        val matchResult = regex.find(text)
        if (matchResult != null) {
            return matchResult.groupValues[1]
        }
        return null
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}