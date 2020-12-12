import 'package:flutter/material.dart';

class About extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "About",
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20),
        children: <Widget>[
          Text(
            "This is a AI powred File Manager. You can actually see the AI when you open any PDF other functions are like a normal File Manager. \n\nYou can control your PDF with your voice and can able to perform functions like \n\n 1. CHANGE PAGE \n 2. READ COMPLETE PAGE OF PDF \n 3. READ A PART OF PAGE",
          ),
          Text("\n Made with ❤️ by UMESH and TEAM")
        ],
      ),
    );
  }
}
