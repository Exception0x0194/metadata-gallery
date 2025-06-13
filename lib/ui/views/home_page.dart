import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../../src/core/constants.dart';
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

  TextEditingController get searchController => viewmodel.searchController;
  FocusNode get searchFocusNode => viewmodel.searchFocusNode;

  final Map<String, PopupMenuItem<String>> orderEntries = {
    prefsOrderByName: PopupMenuItem(
      value: prefsOrderByName,
      child: Text('文件名称'),
    ),
    prefsOrderByLastModified: PopupMenuItem(
      value: prefsOrderByLastModified,
      child: Text('修改时间'),
    ),
  };

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
                focusNode: searchFocusNode,
                onSubmitted: (keyword) => viewmodel.searchImages(keyword),
              ),
              subtitle: Text('检索的元数据内容'),
              trailing: IconButton(
                onPressed: () => viewmodel.searchImages(searchController.text),
                icon: Icon(Icons.waving_hand_outlined),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: ListenableBuilder(
              listenable: viewmodel,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('排序依据：'),
                    PopupMenuButton<String>(
                      child: orderEntries[viewmodel.orderOption]!.child as Text,
                      itemBuilder: (context) => orderEntries.values.toList(),
                      onSelected: (value) => viewmodel.setSortOption(value),
                    ),
                    SizedBox(width: 8.0),
                    Text('倒序'),
                    Checkbox(
                      value: viewmodel.orderReversed,
                      onChanged: (value) => viewmodel.setReversed(value),
                    ),
                  ],
                );
              },
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
    );
  }
}
