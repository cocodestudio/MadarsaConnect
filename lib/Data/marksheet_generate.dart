import 'package:flutter/material.dart';
import 'package:madarsaConnect/Data/loader.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MarksheetPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final Map<String, dynamic> marksData;
  final String selectedYear;
  final String? headLogoUrl;
  final String? headSignatureUrl;
  final String? studentSignatureUrl;

  const MarksheetPreviewScreen({
    super.key,
    required this.studentData,
    required this.marksData,
    required this.selectedYear,
    this.headLogoUrl,
    this.headSignatureUrl,
    this.studentSignatureUrl,
  });

  @override
  _MarksheetPreviewScreenState createState() => _MarksheetPreviewScreenState();
}

class _MarksheetPreviewScreenState extends State<MarksheetPreviewScreen> {
  static pw.Font? _font;
  static pw.Font? _boldFont;

  pw.MemoryImage? _headLogoImage;
  pw.MemoryImage? _headSignatureImage;
  pw.MemoryImage? _studentSignatureImage;

  Uint8List? _pdfBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadFonts() async {
    if (_font == null || _boldFont == null) {
      _font = await PdfGoogleFonts.poppinsRegular();
      _boldFont = await PdfGoogleFonts.poppinsBold();
    }
  }

  Future<pw.MemoryImage?> _fetchImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint("Error fetching image from URL: $e");
    }
    return null;
  }

  Future<void> _prepareImages() async {
    _headLogoImage = await _fetchImage(widget.headLogoUrl);
    _headSignatureImage = await _fetchImage(widget.headSignatureUrl);
    _studentSignatureImage = await _fetchImage(widget.studentSignatureUrl);
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadFonts();
      await _prepareImages();
      final pdf = await _generatePdf(PdfPageFormat.a4, 'Marksheet');
      setState(() {
        _pdfBytes = pdf;
      });
    } catch (e) {
      debugPrint('Error generating PDF: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format, String title) async {
    final defaultLogo = pw.MemoryImage(
      (await rootBundle.load("assets/images/logo.png")).buffer.asUint8List(),
    );

    final doc = pw.Document();

    final examType = widget.studentData['examType'] ?? 'default';
    final records =
        (widget.marksData['records']?[examType]?[widget.selectedYear]
            as Map<String, dynamic>?) ??
        {};
    debugPrint(
      'studentData passed to MarksheetPreviewScreen: ${widget.studentData}',
    );

    final academicYear = widget.studentData['academicYear'] ?? "N/A";
    final duration = widget.studentData['courseDuration'] ?? "N/A";
    final rollNo = widget.studentData['rollNo'] ?? "NA";
    final uniqueId =
        widget.studentData['sucId']?.toString().toUpperCase() ?? 'N/A';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),

        footer:
            (context) => pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Student Signature Section
                    pw.Column(
                      children: [
                        pw.Container(
                          height: 40,
                          width: 80,
                          alignment: pw.Alignment.center,
                          child:
                              _studentSignatureImage != null
                                  ? pw.Image(
                                    _studentSignatureImage!,
                                    height: 60,
                                    width: 100,
                                    fit: pw.BoxFit.contain,
                                  )
                                  : pw.Text(
                                    '(Signature Missing)',
                                    style: pw.TextStyle(
                                      font: _font,
                                      fontSize: 8,
                                      color: PdfColors.grey,
                                    ),
                                  ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '___________________',
                          style: pw.TextStyle(font: _font, fontSize: 10),
                        ),
                        pw.Text(
                          'Student Signature',
                          style: pw.TextStyle(font: _font, fontSize: 10),
                        ),
                      ],
                    ),

                    pw.Column(
                      children: [
                        pw.Container(
                          height: 40,
                          width: 80,
                          alignment: pw.Alignment.center,
                          child:
                              _headSignatureImage != null
                                  ? pw.Image(
                                    _headSignatureImage!,
                                    height: 70,
                                    width: 110,
                                    fit: pw.BoxFit.contain,
                                  )
                                  : pw.Text(
                                    '',
                                    style: pw.TextStyle(
                                      font: _font,
                                      fontSize: 8,
                                      color: PdfColors.grey,
                                    ),
                                  ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '___________________',
                          style: pw.TextStyle(font: _font, fontSize: 10),
                        ),
                        pw.Text(
                          'Head Signature',
                          style: pw.TextStyle(font: _font, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Issued on: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(font: _font, fontSize: 9),
                ),
                pw.Center(
                  child: pw.Text(
                    'This is a system generated marksheet and does not require a signature.',
                    style: pw.TextStyle(font: _font, fontSize: 8),
                  ),
                ),
              ],
            ),

        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      height: 50,
                      width: 50,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        image: pw.DecorationImage(
                          image: _headLogoImage ?? defaultLogo,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        widget.studentData['madarsaName'] ?? 'Institution Name',
                        style: pw.TextStyle(font: _boldFont, fontSize: 28),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Text(
                      uniqueId,
                      style: pw.TextStyle(font: _boldFont, fontSize: 12),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 14),

                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  ),
                  padding: const pw.EdgeInsets.all(14),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Name: ${widget.studentData['fullName'] ?? 'N/A'}',
                        style: pw.TextStyle(font: _boldFont, fontSize: 11),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Father\'s Name: ${widget.studentData['fatherName'] ?? 'N/A'}',
                        style: pw.TextStyle(font: _boldFont, fontSize: 11),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Mother\'s Name: ${widget.studentData['motherName'] ?? 'N/A'}',
                        style: pw.TextStyle(font: _boldFont, fontSize: 11),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'DOB: ${widget.studentData['dateOfBirth'] ?? 'N/A'}',
                        style: pw.TextStyle(font: _boldFont, fontSize: 11),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Roll No: $rollNo',
                        style: pw.TextStyle(font: _boldFont, fontSize: 11),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Duration: $duration',
                        style: pw.TextStyle(font: _boldFont, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                pw.Center(
                  child: pw.Text(
                    widget.studentData['course'] ?? 'Course Name',
                    style: pw.TextStyle(
                      font: _boldFont,
                      fontSize: 16,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),

                pw.TableHelper.fromTextArray(
                  headers: ['Subject', 'Code', 'Obtained', 'Max', 'Grade'],
                  data: [
                    for (var subjectName in records.keys)
                      if (records[subjectName] is Map<String, dynamic>)
                        [
                          subjectName,
                          records[subjectName]['subjectCode'] ?? 'N/A',
                          records[subjectName]['obtainedMarks'] ?? 'N/A',
                          records[subjectName]['maxMarks'] ?? 'N/A',
                          records[subjectName]['grade'] ?? 'N/A',
                        ],
                  ],
                  headerStyle: pw.TextStyle(font: _boldFont, fontSize: 11),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey200,
                  ),
                  cellStyle: pw.TextStyle(font: _font, fontSize: 10),
                  oddRowDecoration: pw.BoxDecoration(color: PdfColors.grey100),
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 20),

                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.blueGrey700,
                      width: 1,
                    ),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Percentage: ${widget.marksData['totalPercentage'] ?? 'N/A'}%',
                        style: pw.TextStyle(font: _boldFont, fontSize: 12),
                      ),
                      pw.Text(
                        'Result: ${widget.marksData['resultStatus'] ?? 'N/A'}',
                        style: pw.TextStyle(
                          font: _boldFont,
                          fontSize: 12,
                          color:
                              (widget.marksData['resultStatus'] ?? '') == 'Pass'
                                  ? PdfColors.green700
                                  : PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Text(
                  'Disclaimer: This marksheet is issued by the institution for academic purposes only.\n\n',
                  style: pw.TextStyle(font: _font, fontSize: 9),
                  textAlign: pw.TextAlign.justify,
                ),
              ],
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  Future<void> _handlePrint() async {
    if (_pdfBytes == null) return;
    await Printing.layoutPdf(onLayout: (format) async => _pdfBytes!);
  }

  Future<void> _handleDownload() async {
    if (_pdfBytes == null) return;
    await Printing.sharePdf(bytes: _pdfBytes!, filename: 'marksheet.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Marksheet Preview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        titleSpacing: 20,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontFamily: 'Gilroy-Bold',
          color: Colors.black,
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GradientSpinner(),
                    SizedBox(height: 16),
                    Text(
                      'Generating Marksheet...',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Gilroy-Bold',
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child:
                        _pdfBytes == null
                            ? const Center(
                              child: Text(
                                'Failed to generate PDF.\nPlease check image URLs and try again.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            )
                            : PdfPreview(
                              build: (format) => _pdfBytes!,
                              canChangePageFormat: false,
                              canChangeOrientation: false,
                              allowPrinting: false,
                              allowSharing: false,
                              padding: const EdgeInsets.all(0),
                              maxPageWidth: 700,
                              pdfFileName: 'marksheet.pdf',
                            ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pdfBytes == null ? null : _handlePrint,
                            icon: const Icon(Icons.print, color: Colors.white),
                            label: const Text(
                              'Print',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _pdfBytes == null ? null : _handleDownload,
                            icon: const Icon(
                              Icons.download,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              'Download',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
