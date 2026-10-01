import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: RegistrationFormScreen(isFirstTime: true),
    );
  }
}

// ** 1. REGISTRATION FORM SCREEN **
class RegistrationFormScreen extends StatefulWidget {
  final bool isFirstTime;
  const RegistrationFormScreen({this.isFirstTime = false});

  @override
  _RegistrationFormScreenState createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  int selectedOption = 1; // 1 = ZAAD, 2 = Bank

  // Option 1 Controllers (Zaad)
  final TextEditingController recipientPhoneController = TextEditingController();
  final TextEditingController zaadPin1Controller = TextEditingController();
  final TextEditingController zaadPin2Controller = TextEditingController();

  // Option 2 Controllers (Salaam Bank - Laga saaray Amount-kii diiwaangelinta)
  final TextEditingController bankAccountNumberController = TextEditingController();
  final TextEditingController bankZaadPinController = TextEditingController();
  final TextEditingController registerPinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Diiwaangelinta Adeegyada", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 0,
        automaticallyImplyLeading: !widget.isFirstTime,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Text("Dooro Nooca Adeegga:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    title: Text("Option 1: ZAAD", style: TextStyle(fontWeight: FontWeight.w600)),
                    value: 1,
                    groupValue: selectedOption,
                    activeColor: Colors.teal,
                    onChanged: (val) => setState(() => selectedOption = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: Text("Option 2: Bank", style: TextStyle(fontWeight: FontWeight.w600)),
                    value: 2,
                    groupValue: selectedOption,
                    activeColor: Colors.teal,
                    onChanged: (val) => setState(() => selectedOption = val!),
                  ),
                ),
              ],
            ),
            Divider(height: 30),

            // **OPTION 1 FIELDS**
            if (selectedOption == 1) ...[
              Text("Dirista Lacagta (ZAAD)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 15),
              TextField(
                controller: recipientPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Numberka lacagta loo dirayo",
                  prefixIcon: Icon(Icons.phone, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: zaadPin1Controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Binka Zaadka (Marka 1aad)",
                  prefixIcon: Icon(Icons.lock, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: zaadPin2Controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Binka Zaadka (Marka 2aad - Xaqiijin)",
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],

            // **OPTION 2 FIELDS (Salaam Bank)**
            if (selectedOption == 2) ...[
              Text("Salaam Bank (*800# Deposit)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 15),
              TextField(
                controller: bankAccountNumberController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: "Numberka Account-ka Bank-ga",
                  prefixIcon: Icon(Icons.account_balance, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: bankZaadPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Binka Zaadka",
                  prefixIcon: Icon(Icons.lock, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: registerPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Register PIN-ka Account-ka",
                  prefixIcon: Icon(Icons.pin, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Steps: *800# -> Zaad PIN -> 5 (Darasalam) -> 2 (Dhigasho) -> Account Number -> Amount (Marka lacagtusoodhacdo) -> 1 -> Register PIN -> 1",
                  style: TextStyle(fontSize: 12, color: Colors.teal[900], height: 1.4),
                ),
              ),
            ],

            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Map<String, String> regData;

                if (selectedOption == 1) {
                  if (recipientPhoneController.text.isEmpty || zaadPin1Controller.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Fadlan buuxi dhammaan meelaha banaan!")),
                    );
                    return;
                  }
                  if (zaadPin1Controller.text != zaadPin2Controller.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Binka Zaad-ka labada jeer la geliyey isku mid ma aha!")),
                    );
                    return;
                  }
                  
                  regData = {
                    'type': 'ZAAD',
                    'phone': recipientPhoneController.text,
                    'pin': zaadPin1Controller.text,
                  };
                } else {
                  if (bankAccountNumberController.text.isEmpty || 
                      bankZaadPinController.text.isEmpty || 
                      registerPinController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Fadlan buuxi dhammaan meelaha banaan!")),
                    );
                    return;
                  }

                  regData = {
                    'type': 'SALAAM BANK',
                    'accountNumber': bankAccountNumberController.text,
                    'zaadPin': bankZaadPinController.text,
                    'registerPin': registerPinController.text,
                  };
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ZaadHomeScreen(registrationData: regData),
                  ),
                );
              },
              child: Text("Keydi oo Diiwaangeli", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ** 2. HOME SCREEN **
class ZaadHomeScreen extends StatefulWidget {
  final Map<String, String> registrationData;
  const ZaadHomeScreen({required this.registrationData});

  @override
  _ZaadHomeScreenState createState() => _ZaadHomeScreenState();
}

class _ZaadHomeScreenState extends State<ZaadHomeScreen> {
  static const platform = MethodChannel('com.example.zaad_auto/ussd');
  
  bool _isPinVisible = false;

  void _openNotificationSettings() async {
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      print("Khalad: $e");
    }
  }

  void _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print("Khalad: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.registrationData;

    return Scaffold(
      appBar: AppBar(
        title: Text('Zaad & Bank Home', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Xogtaadii Diiwaangelinta",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
            ),
            SizedBox(height: 10),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Nooca: ${data['type']}",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal[900]),
                        ),
                        Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                    Divider(color: Colors.teal.shade200, height: 20),
                    if (data['type'] == 'ZAAD') ...[
                      Text("• Numberka Loo Dirayo: ${data['phone']}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "• Binka Zaad-ka: ",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _isPinVisible ? (data['pin'] ?? '') : '****',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(
                              _isPinVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.teal[800],
                            ),
                            onPressed: () {
                              setState(() {
                                _isPinVisible = !_isPinVisible;
                              });
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      Text("• Numberka Account-ka: ${data['accountNumber']}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "• Binka Zaad-ka: ",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _isPinVisible ? (data['zaadPin'] ?? '') : '****',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(
                              _isPinVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.teal[800],
                            ),
                            onPressed: () {
                              setState(() {
                                _isPinVisible = !_isPinVisible;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "• Register PIN-ka: ",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _isPinVisible ? (data['registerPin'] ?? '') : '****',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 25),

            // **DEJINTA OGGOLAANSHAHA**
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.security_rounded, size: 45, color: Colors.teal),
                    SizedBox(height: 8),
                    Text(
                      "Dejinta Oggolaanshaha App-ka",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                    SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _openNotificationSettings,
                      icon: Icon(Icons.notifications_active),
                      label: Text('1. Daari Notification Access'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _openAccessibilitySettings,
                      icon: Icon(Icons.accessibility_new),
                      label: Text('2. Daari Accessibility Service'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 25),

            // **BADHANKA WAX KA BEDELKA**
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegistrationFormScreen(isFirstTime: false)),
                );
              },
              icon: Icon(Icons.edit, color: Colors.teal),
              label: Text('Wax ka bedel Diiwaangelinta', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.teal, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}