import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/app_constants.dart';

class WebTrackerScreen extends StatefulWidget {
  final String url;
  const WebTrackerScreen({super.key, required this.url});

  @override
  State<WebTrackerScreen> createState() => _WebTrackerScreenState();
}

class _WebTrackerScreenState extends State<WebTrackerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /*@override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url)); // Yahan url load hoga
  } */

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // ---> YEH HAI ASLI JADU (User Agent Spoofing) <---
      // Is line se Google ko lagega ki yeh Android ka asli Chrome hai
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Web Expense Tracker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
        ],
      ),
    );
  }
}
