import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fullpdfview/flutter_fullpdfview.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pdf_text/pdf_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum TtsState { playing, stopped, paused, continued }

class PDFScreen extends StatefulWidget {
  final String path;
  PDFScreen({Key key, @required this.path}) : super(key: key);

  _PDFScreenState createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> {
  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = "";
  String lastError = "";
  String lastStatus = "";
  String _currentLocaleId = "";
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();
  String name = "Go to ? ";

  int pages = 0;
  bool isReady = false;
  String errorMessage = '';
  GlobalKey pdfKey = GlobalKey();
  bool isActive = true;
  double scale = 1.0;
  double top = 200.0;
  double initialLocalFocalPoint;

  int limit = 0;

  @override
  void initState() {
    super.initState();
    initTts();
  }

//---------------------------

  PDFDoc _pdfDoc;
  String _text = "";
  File pdf;

  Future _pickPDFText() async {
    pdf = File(widget.path);
    // print(pdf == null
    //     ? "this is null *--------------------------"
    //     : "not null ++++++++++++++++++++");
    _pdfDoc = await PDFDoc.fromFile(pdf);
  }

  Future _readRandomPage(int pageno, String ne) async {
    if (_pdfDoc == null) {
      _onChange("Please wait while document loads.Then try again later.");
      _speak();
      return;
    }
    // setState(() {
    //   _buttonsEnabled = false;
    // });

    String text = await _pdfDoc.pageAt(pageno + 1).text;
    if (ne == "") {
      _onChange(text);
      _speak();
    } else if (text.contains(ne)) {
      List<String> li = text.split(ne);
      String ma = "";
      for (int i = 1; i < li.length; i++) {
        ma = ma + li[i];
      }
      _onChange(ma);
      _speak();
    } else {
      _onChange(
          "Sorry but text you are searching for will not find in this page.");
      _speak();
    }

    setState(() {
      _text = text;
      //_buttonsEnabled = true;
    });
  }

  bool _isinit = true;

  @override
  void didChangeDependencies() async {
    if (_isinit) {
      _isinit = false;
      await _pickPDFText();
    }
    super.didChangeDependencies();
  }

  FlutterTts flutterTts;

  dynamic languages;

  String language;

  double volume = 0.5;

  double pitch = 1.0;

  double rate = 1;

  String _newVoiceText;

  TtsState ttsState = TtsState.stopped;

  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;

  get isPaused => ttsState == TtsState.paused;

  get isContinued => ttsState == TtsState.continued;

  initTts() {
    flutterTts = FlutterTts();

    _getLanguages();

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        _getEngines();
      }
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    if (kIsWeb || Platform.isIOS) {
      flutterTts.setPauseHandler(() {
        setState(() {
          print("Paused");
          ttsState = TtsState.paused;
        });
      });

      flutterTts.setContinueHandler(() {
        setState(() {
          print("Continued");
          ttsState = TtsState.continued;
        });
      });
    }

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  Future _getLanguages() async {
    languages = await flutterTts.getLanguages;
    if (languages != null) setState(() => languages);
  }

  Future _getEngines() async {
    var engines = await flutterTts.getEngines;
    if (engines != null) {
      for (dynamic engine in engines) {
        print(engine);
      }
    }
  }

  Future _speak() async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (_newVoiceText != null) {
      if (_newVoiceText.isNotEmpty) {
        var result = await flutterTts.speak(_newVoiceText);
        if (result == 1) setState(() => ttsState = TtsState.playing);
      }
    }
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  void _onChange(String text) {
    setState(() {
      _newVoiceText = text;
    });
  }

  Future<void> initSpeechState() async {
    bool hasSpeech = await speech.initialize(
        onError: errorListener, onStatus: statusListener);
    if (hasSpeech) {
      _localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale.localeId;
    }

    if (!mounted) return;

    setState(() {
      _hasSpeech = hasSpeech;
    });
  }

  AsyncSnapshot<PDFViewController> snap;

  void startListening(AsyncSnapshot<PDFViewController> snapshot) async {
    snap = snapshot;
    lastWords = "";
    lastError = "";
    await speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 10),
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener,
        cancelOnError: true,
        listenMode: ListenMode.confirmation);

    setState(() {});
  }

  void stopListening() {
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  void resultListener(SpeechRecognitionResult result) async {
    lastWords = "${result.recognizedWords} - ${result.finalResult}";

    print(lastWords);
    if (result.finalResult) {
      print(lastWords);
      name = "Go to ? ";
      setState(() {});

      if (lastWords.contains("read") || lastWords.contains("reading")) {
        _onChange("Please wait");
        _speak();
        List<String> st = lastWords.split(" ");
        int inde = -1;
        for (int i = 0; i < st.length; i++) {
          if (st[i] == "from" || st[i] == "form") {
            inde = i;
            i = st.length;
          }
        }

        String ne = "";
        if (inde != -1 && inde + 1 <= st.length - 1) {
          for (int i = inde + 1; i < st.length; i++) {
            ne = ne + st[i] + " ";
          }

          ne = ne.substring(0, ne.length - 7);
        }

        int d = await snap.data.getCurrentPage();
        _readRandomPage(d, ne);
      } else {
        int page = -1;
        List<String> s = lastWords.split(" ");
        for (int i = 0; i < s.length; i++) {
          if (int.tryParse(s[i]) != null) {
            page = int.parse(s[i]);
          }
        }
        // print(pages.toString() + "______" + page.toString());
        if (page != -1 && page <= pages && page >= 0) {
          snap.data.setPage(page - 1);
        } else if (page == -1) {
          _onChange("Sorry, voice not clearly audible please try again");
          _speak();
        } else {
          _onChange("This PDF has only " + pages.toString() + " pages.");
          _speak();
        }
      }
    }
    //});
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // print("sound level $level: $minSoundLevel - $maxSoundLevel ");
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    // print("Received error status: $error, listening: ${speech.isListening}");
    setState(() {
      lastError = "${error.errorMsg} - ${error.permanent}";
    });
  }

  void statusListener(String status) {
    // print(
    // "Received listener status: $status, listening: ${speech.isListening}");
    setState(() {
      lastStatus = "$status";
    });
  }

  _switchLang(selectedVal) {
    setState(() {
      _currentLocaleId = selectedVal;
    });
    print(selectedVal);
  }

  // +++++++++++++++++++++++++++++++++++  speek

  @override
  void dispose() {
    super.dispose();
    flutterTts.stop();
  }

  // ++++++++++++++++++++++++++++++++++++  speak

  @override
  Widget build(BuildContext context) {
    if (limit == 0) {
      initSpeechState();

      limit = 10;
    }
    return OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
      if (orientation == Orientation.portrait) {
        final Completer<PDFViewController> _controller =
            Completer<PDFViewController>();
        return Scaffold(
          appBar: AppBar(
            title: Text("Document"),
            actions: <Widget>[
              // IconButton(
              //   icon: Icon(Icons.share),
              //   onPressed: () {},
              // ),
            ],
          ),
          body: Stack(
            children: <Widget>[
              Container(
                color: Colors.black,
                child: PDFView(
                    key: pdfKey,
                    filePath: widget.path,
                    fitEachPage: true,
                    fitPolicy: FitPolicy.BOTH,
                    dualPageMode: false,
                    enableSwipe: true,
                    swipeHorizontal: true,
                    autoSpacing: true,
                    pageFling: true,
                    defaultPage: 0,
                    pageSnap: true,
                    backgroundColor: bgcolors.BLACK,
                    onRender: (_pages) {
                      print("OK RENDERED!!!!!");
                      setState(() {
                        pages = _pages;
                        isReady = true;
                      });
                    },
                    onError: (error) {
                      setState(() {
                        errorMessage = error.toString();
                      });
                      print(error.toString());
                    },
                    onPageError: (page, error) {
                      setState(() {
                        errorMessage = '$page: ${error.toString()}';
                      });
                      print('$page: ${error.toString()}');
                    },
                    onViewCreated: (PDFViewController pdfViewController) {
                      _controller.complete(pdfViewController);
                    },
                    onPageChanged: (int page, int total) {
                      print('page change: $page/$total');
                    },
                    onZoomChanged: (double zoom) {
                      print("Zoom is now $zoom");
                    }),
              ),
              errorMessage.isEmpty
                  ? !isReady
                      ? Center(
                          child: CircularProgressIndicator(),
                        )
                      : Container()
                  : Center(child: Text(errorMessage))
            ],
          ),
          floatingActionButton: FutureBuilder<PDFViewController>(
            future: _controller.future,
            builder: (context, AsyncSnapshot<PDFViewController> snapshot) {
              if (snapshot.hasData) {
                return FloatingActionButton.extended(
                  icon: Icon(
                    Icons.mic_none,
                    color: Colors.white,
                  ),
                  label: Text(name),
                  onPressed: () {
                    // speech.isListening ? cancelListening : null;

                    // !_hasSpeech || speech.isListening
                    //     ? null
                    //     : await startListening;
                    if (isPlaying) {
                      _stop();
                    } else {
                      setState(() {
                        name = "Listening ...";
                      });

                      startListening(snapshot);
                    }

                    // print(snapshot.data.toString() + "_________________________");

                    //print(lastWords + "_____umehs__________________");

                    // print(await snapshot.data.getZoom());
                    // print(await snapshot.data.getPageWidth(1));
                    // print(await snapshot.data.getPageHeight(1));
                    // // page = 5;
                    // //await snapshot.data.setPage(pages ~/ 2);
                    // await snapshot.data.resetZoom(1);
                    // await snapshot.data.setPage(3);
                    // //print(await snapshot.data.getScreenWidth());
                  },
                );
              }

              return Container();
            },
          ),
        );
      } else {
        final Completer<PDFViewController> _controller =
            Completer<PDFViewController>();
        return PDFView(
          filePath: widget.path,
          fitEachPage: false,
          dualPageMode: true,
          displayAsBook: true,
          dualPageWithBreak: true,
          enableSwipe: true,
          swipeHorizontal: true,
          autoSpacing: false,
          pageFling: true,
          defaultPage: 0,
          pageSnap: true,
          backgroundColor: bgcolors.BLACK,
          onRender: (_pages) {
            print("OK RENDERED!!!!!");
            setState(() {
              pages = _pages;
              isReady = true;
            });
          },
          onError: (error) {
            setState(() {
              errorMessage = error.toString();
            });
            print(error.toString());
          },
          onPageError: (page, error) {
            setState(() {
              errorMessage = '$page: ${error.toString()}';
            });
            print('$page: ${error.toString()}');
          },
          onViewCreated: (PDFViewController pdfViewController) {
            _controller.complete(pdfViewController);
          },
          onPageChanged: (int page, int total) {
            print('page change: $page/$total');
          },
        );
      }
    });
  }
}
