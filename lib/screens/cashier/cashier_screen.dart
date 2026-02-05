import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:idn_post/models/products.dart';
import 'package:idn_post/screens/cashier/components/checkout_panel.dart';
import 'package:idn_post/screens/cashier/components/printer_selector.dart';
import 'package:idn_post/screens/cashier/components/product_card.dart';
import 'package:idn_post/screens/cashier/components/qr_result_modal.dart';
import 'package:idn_post/utils/currency_format.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;
  final Map<Product, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  // LOGIKA BLUETOOTH
  Future<void> _initBluetooth() async {
    // minta izin lokasi dan bluetooth (WAJIB),
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    List<BluetoothDevice> devices = [
      // list ini akan otomatis terisi jika BT di hp menyala dan sudah ada devices yang siap dikoneksikan
    ];
    try {
      devices = await bluetooth.getBondedDevices();
    } catch (e) {
      debugPrint("Erorr Bluetooth: $e");
    }

    if (mounted) {
      setState(() {
        _devices = devices;
      });
    }

    bluetooth.onStateChanged().listen((state) {
      if (mounted) {
        setState(() {
          _connected = state == BlueThermalPrinter.CONNECTED;
        });
      }
    });
  }

  void _connectToDevice(BluetoothDevice? device) {
    // kondisi utama yang mempelopori if - if selanjutnya
    if (device != null) {
      // if yang merupakan anak/cabang dari if utama,
      // if ini memiliki sebuah kondisi yang menjawab pertanyaan/statement dari kondisi utama
      bluetooth.isConnected.then((isConnected) {
        if (isConnected == false) {
          bluetooth.connect(device).catchError((error) {
            // id ini wajib memiliki opini yang sama, sperti if kedua
            if (mounted) setState(() => _connected = false);
          });
          // statement didalam if ini akan di jalankan ketika if sebelumnya tdk terpenuhi
          // if ini adalah opsi terakhir yang akan dijalankan ketika if-if sebelumnya tidak terpenuhi (tdk berjalan)
          if (mounted)
            setState(() => _selectedDevice = device); // nilai true nya
        }
      });
    }
  }

  // LOGIKA CART
  void _addToCart(Product product) {
    //
    setState(() {
      _cart.update(
        // untuk mendefinisikan produk yang ada di menu
        product,
        //  // logika matematis, yang dijalankan ketika 1 product sudah berada di keranjang, dan user klik +, yg nantinya jumlahnya akan ditambah 1
        (value) => value + 1,
        // jika user tidak menambahkan lagi jumlah produk(hanya 1), maka default jumlah dari barang tersebut adalah satu
        ifAbsent: () => 1,
      );
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      if (_cart.containsKey(product) && _cart[product]! > 1) {
        _cart[product] = _cart[product]! - 1;
      } else {
        _cart.remove(product);
      }
    });
  }

  int _calculateTotal() {
    int total = 0;
    _cart.forEach((key, value) => total += (key.price * value));
    return total;
  }

  // LOGIKA PRINTING
  void _handlePrint() async {
    int total = _calculateTotal();
    if (total == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Keranjang masih kosong!')));
    }

    String trxId =
        "TRX-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}";
    String qrData = "PAY:$trxId:$total";
    bool isPrinting = false;

    // menyiapkan tanggal saat ini (current date)
    DateTime now = DateTime.now();
    String formattedDate = DateFormat(
      'dd-MM-yyyy HH:mm',
    ).format(now); // menapilkan data yang rapih

    // LAYOUTING STRUK
    if (_selectedDevice != null && await bluetooth.isConnected == true) {
      // header struk
      bluetooth.printNewLine(); // untuk ngasih enter
      bluetooth.printCustom("IDN CAFE", 3, 1); // judul besar atau locasi center
      bluetooth.printNewLine();
      bluetooth.printCustom(
        "Jl. Bagus Dayeuh",
        1,
        1,
      ); // alamat posisinya center

      // tanggal dan id
      bluetooth.printNewLine();
      bluetooth.printLeftRight("Waktu:", formattedDate, 1);

      // daftar items
      bluetooth.printCustom("--------------------------------", 1, 1);
      _cart.forEach((product, qty) {
        String priceTotal = formatRupiah(product.price * qty);
        //cetak nama barang dikali qty
        // cetak nama barang
        bluetooth.printLeftRight("${product.name} x${qty}", priceTotal, 1);
      });
      bluetooth.printCustom("--------------------------------", 1, 1);

      // total & QR
      bluetooth.printLeftRight("TOTAL", formatRupiah(total), 3);
      bluetooth.printNewLine();
      bluetooth.printCustom("SCAN QR DI BAWAH:", 1, 1);
      bluetooth.printQRcode(qrData, 200, 200, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Thank You!", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      isPrinting = true;
    }

    // untuk menampilkan modal hasil qr code (PopUp)
    _showQRModal(qrData, total, isPrinting);
  }

  void _showQRModal(String qrData, int total, bool isPrinting) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QrResultModal(
        qrData: qrData,
        total: total,
        isPrinting: isPrinting,
        onClosed: () => Navigator.pop(context),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Menu Kasir",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // dropdown select printer
          PrinterSelector(
            devices: _devices,
            selectedDevice: _selectedDevice,
            isConnected: _connected,
            onSelected: _connectToDevice,
          ),
          
          // Grid for product list
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // menampilkan 2 aja secara horizontal
                childAspectRatio: 0.8, // jarak dari setiap grid
                crossAxisSpacing: 15, // spasi antar grid tapi tdk searah dgn spacing yg asli
                mainAxisSpacing: 15,
              ),
              itemCount: menus.length, // length ngambil keseluruhan dari menu
              itemBuilder: (context, index) {
                final product  = menus[index];
                final qty = _cart[product] ?? 0;

                // pemanggilan product list pada product card
                return ProductCard(
                  product: product,
                  qty: qty,
                  onAdd: () => _addToCart(product),
                  onRemove: () => _removeFromCart(product),
                );
              },
            ),
          ),

          // button sheet panel
          CheckoutPanel(
            total: _calculateTotal(),
            onPressed: _handlePrint,
          )
        ],
      ),
    );
  }
}