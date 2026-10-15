import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  bool isRegistered = prefs.getBool('isRegistered') ?? false;
  String type = prefs.getString('type') ?? 'SALAAM BANK';
  
  Map<String, String> initialData = {
    'type': type,
    'phone': prefs.getString('phone') ?? '',
    'zaadPin': prefs.getString('zaadPin') ?? '',
    'accountNumber': prefs.getString('accountNumber') ?? '0634187078',
    'registerPin': prefs.getString('registerPin') ?? '2211',
  };

  runApp(MyApp(isRegistered: isRegistered, initialData: initialData));
}

class MyApp extends StatelessWidget {
  final bool isRegistered;
  final Map<String, String> initialData;

  const MyApp({required this.isRegistered, required this.initialData});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: !isRegistered 
          ? RegistrationFormScreen(isFirstTime: true) 
          : LicenseCheckWrapper(child: ZaadHomeScreen(registrationData: initialData)),
    );
  }
}

class LicenseCheckWrapper extends StatefulWidget {
  final Widget child;
  const LicenseCheckWrapper({required this.child});

  @override
  _LicenseCheckWrapperState createState() => _LicenseCheckWrapperState();
}

class _LicenseCheckWrapperState extends State<LicenseCheckWrapper> {
  bool _isLoading = true;
  bool _isLicensed = false;
  String _deviceId = '';
  final TextEditingController _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String? deviceId = prefs.getString('app_device_id');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = "74EDF0753D14ADFE";
      await prefs.setString('app_device_id', deviceId);
    }

    String? activationKey = prefs.getString('activation_key');
    
    bool licensed = false;
    if (activationKey != null && activationKey.isNotEmpty) {
      licensed = await _validateKeyLocally(activationKey, deviceId, prefs);
    }

    setState(() {
      _deviceId = deviceId!;
      _isLicensed = licensed;
      _isLoading = false;
    });
  }

  Future<bool> _validateKeyLocally(String key, String deviceId, SharedPreferences prefs) async {
    try {
      String? lastUsedKey = prefs.getString('last_used_activation_key');
      if (lastUsedKey != null && lastUsedKey == key) {
        return false;
      }

      List<String> parts = key.split('-');
      if (parts.length >= 3) {
        String keyDeviceId = parts[1];
        if (keyDeviceId != deviceId) {
          return false;
        }

        int expiryMillis = 0;
        for (var part in parts) {
          if (part.length > 8 && int.tryParse(part) != null) {
            expiryMillis = int.parse(part);
            break;
          }
        }

        if (expiryMillis == 0) {
          expiryMillis = int.tryParse(parts[parts.length - 2]) ?? int.tryParse(parts.last) ?? 0;
        }

        if (expiryMillis > 0) {
          DateTime expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
          return DateTime.now().isBefore(expiryDate);
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  void _openWhatsApp() async {
    String phoneNumber = "252634187078";
    String message = "Asc, waxaan rabaa Activation Key-ga cusub ee bishan. Device ID-gaygu waa: $_deviceId";
    
    var url = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        var fallbackUrl = Uri.parse("whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lama helin barnaamij WhatsApp ah oo qalabkan ku jira!")),
          );
        }
      }
    } catch (e) {
      print("Khalad WhatsApp: $e");
    }
  }

  void _saveKey() async {
    String key = _keyController.text.trim();
    if (key.isEmpty) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastUsedKey = prefs.getString('last_used_activation_key');

    if (lastUsedKey == key) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Koodhkan bishii hore ayaa la isticmaalay, fadlan koodhka bisha cusub soo dalbo!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (await _validateKeyLocally(key, _deviceId, prefs)) {
      await prefs.setString('activation_key', key);
      await prefs.setString('last_used_activation_key', key);
      
      setState(() {
        _isLicensed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Laysanka bisha cusub waa la aqbalay!"), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Koodhka aad gelisay waa khalad, waa dhacay ama waa koodhkii hore!"), backgroundColor: Colors.red),
      );
    }
  }

  void _showAdminPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Oggolaanshaha Admin-ka", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Geli Password-ka Admin-ka si aad u gasho qaybta key generator-ka:"),
              SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: "Password-ka",
                  prefixIcon: Icon(Icons.lock, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Ka noqor", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String savedPassword = prefs.getString('admin_password') ?? "1234";

                if (passwordController.text.trim() == savedPassword) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AdminKeyGeneratorScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Password-ku waa khalad!"), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text("Gali", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    if (!_isLicensed) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Fadlan Lacag Ku Shubbo (Laysan)", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal,
          actions: [
            IconButton(
              icon: Icon(Icons.admin_panel_settings),
              onPressed: _showAdminPasswordDialog,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_clock, size: 70, color: Colors.orange[800]),
              SizedBox(height: 20),
              Text(
                "Waqtigii bishii la soo dhaafay waa ka dhamaaday ama Laysan cusub lama helin. Fadlan koodhka bisha cusub ku shubo.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
              SizedBox(height: 20),
              Text("Device ID-gaaga qalabkan:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(_deviceId, style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.teal),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _deviceId));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Device ID waa la koorobay!")));
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  labelText: "Geli Koodhka Furaha (Activation Key)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: EdgeInsets.symmetric(vertical: 14)),
                onPressed: _saveKey,
                child: Text("Xaqiiji Koodhka", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 15),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(vertical: 14)),
                onPressed: _openWhatsApp,
                icon: Icon(Icons.chat, color: Colors.white),
                label: Text("Koodhka Bisha Cusub Dalbo (WhatsApp)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

class AdminKeyGeneratorScreen extends StatefulWidget {
  @override
  _AdminKeyGeneratorScreenState createState() => _AdminKeyGeneratorScreenState();
}

class _AdminKeyGeneratorScreenState extends State<AdminKeyGeneratorScreen> {
  final TextEditingController _adminDeviceIdController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: "30");
  final TextEditingController _newPasswordController = TextEditingController();
  String _generatedKeyResult = "";

  void _generateKeyForCustomer() {
    String deviceId = _adminDeviceIdController.text.trim();
    int days = int.tryParse(_daysController.text.trim()) ?? 30;

    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fadlan geli Device ID-ga macmiilka!"), backgroundColor: Colors.red),
      );
      return;
    }

    int expiryMillis = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    // Isticmaalka timestamp-ka saxda ah iyo laba random values si uusan waligiis u soo bixin koodh hore
    int uniqueSalt = DateTime.now().microsecondsSinceEpoch;
    int randomSuffix = Random().nextInt(999999);

    setState(() {
      _generatedKeyResult = "ZAAD-$deviceId-$expiryMillis-$uniqueSalt-$randomSuffix";
    });
  }

  void _changeAdminPassword() async {
    String newPassword = _newPasswordController.text.trim();
    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fadlan geli password-ka cusub!"), backgroundColor: Colors.red),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_password', newPassword);
    _newPasswordController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Password-ka Admin-ka waa la beddelay!"), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Key Generator", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Text("Soo Saar Koodhka Bisha Cusub (Admin)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800])),
            SizedBox(height: 15),
            TextField(
              controller: _adminDeviceIdController,
              decoration: InputDecoration(
                labelText: "Device ID-ga Macmiilka",
                prefixIcon: Icon(Icons.devices, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Maalmaha La Siiyayo (Tusaale: 30)",
                prefixIcon: Icon(Icons.calendar_today, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _generateKeyForCustomer,
              child: Text("Key-ga Bisha Cusub Soo Saar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            SizedBox(height: 25),
            if (_generatedKeyResult.isNotEmpty) ...[
              Text("Koodhka La Soo Saaray:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[750])),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _generatedKeyResult,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.teal),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedKeyResult));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Key-ga waa la koorobay!")),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            Divider(height: 40, thickness: 1.5),
            
            Text("Beddel Password-ka Admin-ka", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[800])),
            SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password Cusub Geli",
                prefixIcon: Icon(Icons.lock_reset, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _changeAdminPassword,
              child: Text("Beddel Password-ka", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class RegistrationFormScreen extends StatefulWidget {
  final bool isFirstTime;
  const RegistrationFormScreen({this.isFirstTime = false});

  @override
  _RegistrationFormScreenState createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  int selectedOption = 1;

  final TextEditingController recipientPhoneController = TextEditingController();
  final TextEditingController zaadPin1Controller = TextEditingController();
  final TextEditingController zaadPin2Controller = TextEditingController();

  final TextEditingController bankAccountNumberController = TextEditingController();
  final TextEditingController bankZaadPinController = TextEditingController();
  final TextEditingController registerPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String type = prefs.getString('type') ?? 'ZAAD';
    setState(() {
      selectedOption = (type == 'ZAAD') ? 1 : 2;
      recipientPhoneController.text = prefs.getString('phone') ?? '';
      zaadPin1Controller.text = prefs.getString('zaadPin') ?? '';
      zaadPin2Controller.text = prefs.getString('zaadPin') ?? '';
      bankAccountNumberController.text = prefs.getString('accountNumber') ?? '';
      bankZaadPinController.text = prefs.getString('zaadPin') ?? '';
      registerPinController.text = prefs.getString('registerPin') ?? '';
    });
  }

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
                    title: Text("ZAAD", style: TextStyle(fontWeight: FontWeight.w600)),
                    value: 1,
                    groupValue: selectedOption,
                    activeColor: Colors.teal,
                    onChanged: (val) => setState(() => selectedOption = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: Text("Salaam Bank", style: TextStyle(fontWeight: FontWeight.w600)),
                    value: 2,
                    groupValue: selectedOption,
                    activeColor: Colors.teal,
                    onChanged: (val) => setState(() => selectedOption = val!),
                  ),
                ),
              ],
            ),
            Divider(height: 30),

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
            ],

            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();

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

                  await prefs.setString('type', 'ZAAD');
                  await prefs.setString('phone', recipientPhoneController.text);
                  await prefs.setString('zaadPin', zaadPin1Controller.text);
                } else {
                  if (bankAccountNumberController.text.isEmpty || 
                      bankZaadPinController.text.isEmpty || 
                      registerPinController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Fadlan buuxi dhammaan meelaha banaan!")),
                    );
                    return;
                  }

                  await prefs.setString('type', 'SALAAM BANK');
                  await prefs.setString('accountNumber', bankAccountNumberController.text);
                  await prefs.setString('zaadPin', bankZaadPinController.text);
                  await prefs.setString('registerPin', registerPinController.text);
                }

                await prefs.setBool('isRegistered', true);

                Map<String, String> regData = {
                  'type': prefs.getString('type') ?? 'SALAAM BANK',
                  'phone': prefs.getString('phone') ?? '',
                  'zaadPin': prefs.getString('zaadPin') ?? '',
                  'accountNumber': prefs.getString('accountNumber') ?? '',
                  'registerPin': prefs.getString('registerPin') ?? '',
                };

                if (widget.isFirstTime) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LicenseCheckWrapper(
                        child: ZaadHomeScreen(registrationData: regData),
                      ),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ZaadHomeScreen(registrationData: regData),
                    ),
                  );
                }
              },
              child: Text("Keydi oo Diiwaangeli", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class ZaadHomeScreen extends StatefulWidget {
  final Map<String, String> registrationData;
  const ZaadHomeScreen({required this.registrationData});

  @override
  _ZaadHomeScreenState createState() => _ZaadHomeScreenState();
}

class _ZaadHomeScreenState extends State<ZaadHomeScreen> {
  static const platform = MethodChannel('com.example.zaad_auto/ussd');
  bool _isPinVisible = false;
  
  bool _autoTransferOn = true;
  bool _checkBalanceOn = false;
  bool _notificationAccessOn = false;
  String _timeRemainingText = "30d 0h";
  String _deviceId = "74EDF0753D14ADFE";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _calculateRemainingTime();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? devId = prefs.getString('app_device_id');
    setState(() {
      _autoTransferOn = prefs.getBool('auto_transfer_on') ?? true;
      _checkBalanceOn = prefs.getBool('check_balance_on') ?? false;
      _notificationAccessOn = prefs.getBool('notification_access_on') ?? false;
      if (devId != null && devId.isNotEmpty) {
        _deviceId = devId;
      }
    });
  }

  void _calculateRemainingTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? activationKey = prefs.getString('activation_key');
    
    if (activationKey == null || activationKey.isEmpty) {
      return;
    }

    try {
      List<String> parts = activationKey.split('-');
      if (parts.length >= 2) {
        int expiryMillis = 0;
        for (var part in parts) {
          if (part.length > 8 && int.tryParse(part) != null) {
            expiryMillis = int.parse(part);
            break;
          }
        }
        if (expiryMillis == 0) {
          expiryMillis = int.tryParse(parts[parts.length - 2]) ?? int.tryParse(parts.last) ?? 0;
        }

        if (expiryMillis > 0) {
          DateTime expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
          Duration remaining = expiryDate.difference(DateTime.now());

          if (remaining.isNegative) {
            setState(() {
              _timeRemainingText = "Waqti La'aan";
            });
          } else {
            int days = remaining.inDays;
            int hours = remaining.inHours % 24;
            setState(() {
              _timeRemainingText = "${days}d ${hours}h";
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _timeRemainingText = "0d 0h";
      });
    }
  }

  void _updateAutoTransfer(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_transfer_on', value);
    setState(() {
      _autoTransferOn = value;
    });
  }

  void _updateCheckBalance(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('check_balance_on', value);
    setState(() {
      _checkBalanceOn = value;
    });
  }

  void _updateNotificationAccess(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_access_on', value);
    setState(() {
      _notificationAccessOn = value;
    });
    if (value) {
      try {
        await platform.invokeMethod('openNotificationSettings');
      } catch (e) {
        print("Khalad: $e");
      }
    }
  }

  void _triggerCheckBalance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flutter.manual_check', true);
    
    try {
      await platform.invokeMethod('dialUssd', {'code': '*882#'});
    } catch (e) {
      print("Khalad USSD: $e");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Waxaa la bilaabay Check Balance (*882#)...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.registrationData;
    String displayType = data['type'] ?? 'SALAAM BANK';
    if (displayType == 'CHECK_BALANCE') {
      displayType = 'SALAAM BANK';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Zaad & Bank Home', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.app_registration, color: Colors.white),
            tooltip: "Beddel Diiwaangelinta",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RegistrationFormScreen(isFirstTime: false),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Xogtaadii Diiwaangelinta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800])),
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
                        Text("Nooca: $displayType", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal[900])),
                        Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
                    Divider(color: Colors.teal.shade200, height: 20),
                    
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Lacag Dirista Auto (Notification)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal[900])),
                      value: _autoTransferOn,
                      activeColor: Colors.teal,
                      onChanged: _updateAutoTransfer,
                    ),
                    Divider(color: Colors.teal.shade200, height: 10),

                    if (displayType == 'ZAAD') ...[
                      Text("• Numberka Loo Dirayo: ${data['phone']}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ] else ...[
                      Text("• Account-ka Bank-ga: ${data['accountNumber']}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      Text("• Register PIN-ka: ${data['registerPin']}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text("• Binka Zaad-ka: ", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        Text(
                          _isPinVisible ? (data['zaadPin'] ?? '') : '****',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(_isPinVisible ? Icons.visibility : Icons.visibility_off, color: Colors.teal[800]),
                          onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.security_rounded, size: 45, color: Colors.teal),
                    SizedBox(height: 8),
                    Text("Dejinta Oggolaanshaha App-ka", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    SizedBox(height: 10),
                    
                    SwitchListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                      title: Text("Notification Access", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])),
                      value: _notificationAccessOn,
                      activeColor: Colors.teal,
                      onChanged: _updateNotificationAccess,
                    ),
                    Divider(height: 15),
                    
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                        child: Text("BALANCE CHECKER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                      title: Text("Active Check Balance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])),
                      value: _checkBalanceOn,
                      activeColor: Color(0xFFE91E63),
                      onChanged: _updateCheckBalance,
                    ),
                    Divider(height: 15),

                    ElevatedButton(
                      onPressed: _triggerCheckBalance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Check Balance Now!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "SUBSCRIPTION STATUS",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Device ID",
                              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _deviceId,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: _deviceId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Device ID waa la koorobay!")),
                                    );
                                  },
                                  child: Icon(Icons.copy, size: 16, color: Colors.teal[700]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Time Left",
                              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _timeRemainingText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[900],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}