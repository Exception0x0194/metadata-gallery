import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../viewmodels/home_page_viewmodel.dart';
import '../widgets/image_card.dart';
import 'scan_progress_indicator.dart';

class HomePage extends StatefulWidget {
  final HomePageViewmodel viewmodel = GetIt.I();

  HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomePageViewmodel get viewmodel => widget.viewmodel;

  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: ListTile(
              title: TextField(
                controller: searchController,
                onSubmitted: (keyword) => viewmodel.searchImages(keyword),
              ),
              subtitle: Text('检索的元数据内容'),
              trailing: IconButton(
                onPressed: () => viewmodel.searchImages(searchController.text),
                icon: Icon(Icons.waving_hand_outlined),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: viewmodel,
            builder: (context, child) => Expanded(
              child: Stack(
                alignment: AlignmentDirectional.topEnd,
                children: [
                  WaterfallFlow.builder(
                    itemCount: viewmodel.searchResult.length,
                    gridDelegate:
                        SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                        ),
                    itemBuilder: (context, idx) {
                      return ImageCard(image: viewmodel.searchResult[idx]);
                    },
                  ),
                  ScanProgressIndicator(
                    viewmodel: viewmodel.scanProgressIndicatorViewmodel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => viewmodel.callScan(),
        child: Icon(Icons.refresh_outlined),
      ),
      // floatingActionButton: Column(
      //   mainAxisSize: MainAxisSize.min,
      //   children: [
      //     FloatingActionButton(
      //       onPressed: () {
      //         if (nameController.text.isEmpty) return;
      //         setState(() {
      //           text = greet(name: nameController.text);
      //         });
      //       },
      //       child: Icon(Icons.waving_hand),
      //     ),
      // SizedBox(height: 8.0),
      // FloatingActionButton(
      //   onPressed: () async {
      //     final pickResult = await ImagePicker().pickImage(
      //       source: ImageSource.gallery,
      //     );
      //     if (pickResult == null) return;
      //     final fileBytes = await pickResult.readAsBytes();
      //     try {
      //       setState(() {
      //         text = extractMetadata(inputBytes: fileBytes);
      //       });
      //     } on PanicException catch (e) {
      //       setState(() {
      //         text = 'Rust panicked: $e';
      //       });
      //     } catch (e) {
      //       setState(() {
      //         text = 'Rust returned error: $e';
      //       });
      //     }
      //   },
      //   child: Icon(Icons.photo_outlined),
      // ),
      // ],
      // ),
    );
  }
}
