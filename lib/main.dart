import 'package:flutter/material.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// FFI Definitions
typedef InitBmpC = Int32 Function(Pointer<Utf8>, Int32, Int32);
typedef InitBmpDart = int Function(Pointer<Utf8>, int, int);

typedef AppendBmpC = Int32 Function(Pointer<Utf8>, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32);
typedef AppendBmpDart = int Function(Pointer<Utf8>, int, int, int, int, int, int, int, int, int);

final DynamicLibrary engineLib = Platform.isAndroid
    ? DynamicLibrary.open('libfractal_engine.so')
    : DynamicLibrary.process();

final InitBmpDart initBmp = engineLib
    .lookup<NativeFunction<InitBmpC>>('init_bmp')
    .asFunction();

final AppendBmpDart appendBmpRows = engineLib
    .lookup<NativeFunction<AppendBmpC>>('append_bmp_rows')
    .asFunction();

void main() => runApp(const EngineApp());

class EngineApp extends StatelessWidget {
  const EngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ControlPanel(),
    );
  }
}

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  String? imagePath;
  bool isComputing = false;
  double progressValue = 0.0;
  int computeTime = 0;
  
  final TextEditingController sizeController = TextEditingController(text: "1000");

  Future<void> _runEngine() async {
    int gridSize = int.tryParse(sizeController.text) ?? 1000;
    
    setState(() {
      isComputing = true;
      progressValue = 0.0;
      imagePath = null;
    });

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/output_matrix.bmp';
    final Pointer<Utf8> pathPtr = path.toNativeUtf8();

    final stopwatch = Stopwatch()..start();
    
    // 1. Initialize empty BMP file
    initBmp(pathPtr, gridSize, gridSize);
    
    // 2. Compute in chunks to prevent UI thread lock
    int chunkSize = 20; // Process 20 rows at a time
    
    for (int y = 0; y < gridSize; y += chunkSize) {
      int rowsToProcess = (y + chunkSize > gridSize) ? gridSize - y : chunkSize;
      
      // b_min, b_max, s_min, s_max, width, height, max_iter, start_row, num_rows
      appendBmpRows(pathPtr, 2, 500, 2, 500, gridSize, gridSize, 1000, y, rowsToProcess);
      
      setState(() {
        progressValue = (y + rowsToProcess) / gridSize;
      });
      
      // Yield to the UI thread so Flutter can update the progress bar
      await Future.delayed(const Duration(milliseconds: 1));
    }
    
    stopwatch.stop();
    calloc.free(pathPtr);

    setState(() {
      imagePath = path;
      computeTime = stopwatch.elapsedMilliseconds;
      isComputing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), 
      body: SafeArea(
        child: Column(
          children: [
            // Control Interface
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 4)),
              ),
              child: Row(
                children: [
                  const Text('RESOLUTION (PX):', style: TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: sizeController,
                      enabled: !isComputing,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 18),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFF111111),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFF555555), width: 2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFF555555), width: 2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFF888888), width: 2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Image Display area
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  border: Border(
                    top: BorderSide(color: Color(0xFF444444), width: 3),
                    left: BorderSide(color: Color(0xFF444444), width: 3),
                    bottom: BorderSide(color: Color(0xFF111111), width: 3),
                    right: BorderSide(color: Color(0xFF111111), width: 3),
                  ),
                ),
                child: Center(
                  child: imagePath != null
                    ? InteractiveViewer(
                        minScale: 0.1,
                        maxScale: 20.0,
                        child: Image.file(
                          File(imagePath!),
                          filterQuality: FilterQuality.none, 
                        ),
                      )
                    : const Text('AWAITING INPUT', style: TextStyle(color: Color(0xFF555555))),
                ),
              ),
            ),

            // Progress and Metrics
            if (isComputing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Text('PROCESSING: ${(progressValue * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF888888), fontFamily: 'monospace')),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: const Color(0xFF111111),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF888888)),
                      minHeight: 12,
                    ),
                  ],
                ),
              ),

            if (!isComputing && imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('COMPUTED IN ${computeTime}ms',
                    style: const TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'monospace')),
              ),

            // Execution Button
            GestureDetector(
              onTap: isComputing ? null : _runEngine,
              child: Container(
                height: 60,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: isComputing ? const Color(0xFF333333) : const Color(0xFF555555),
                  border: Border(
                    top: BorderSide(color: isComputing ? const Color(0xFF222222) : const Color(0xFF888888), width: 4),
                    left: BorderSide(color: isComputing ? const Color(0xFF222222) : const Color(0xFF888888), width: 4),
                    bottom: BorderSide(color: isComputing ? const Color(0xFF888888) : const Color(0xFF222222), width: 4),
                    right: BorderSide(color: isComputing ? const Color(0xFF888888) : const Color(0xFF222222), width: 4),
                  ),
                ),
                child: Center(
                  child: Text(
                    isComputing ? 'EXECUTING...' : 'INITIATE CALCULATION',
                    style: TextStyle(
                      color: isComputing ? const Color(0xFF666666) : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
