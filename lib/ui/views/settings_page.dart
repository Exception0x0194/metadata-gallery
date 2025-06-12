import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../viewmodels/settings_page_viewmodel.dart';

class SettingsPage extends StatefulWidget {
  final SettingsPageViewmodel viewmodel = GetIt.I();

  SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsPageViewmodel get viewmodel => widget.viewmodel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewmodel,
      builder: (context, child) {
        final folders = viewmodel.foldersToScan ?? [];
        return Scaffold(
          body: ListView.builder(
            itemCount: folders.length + 1,
            itemBuilder: (context, idx) {
              if (idx == folders.length) {
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('添加文件夹...'),
                    onTap: () => viewmodel.browseAndAddFolder(),
                  ),
                );
              }
              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(folders[idx]),
                  trailing: IconButton(
                    onPressed: () => viewmodel.removeFolderToScan(idx),
                    icon: Icon(Icons.delete_outline),
                  ),
                  onTap: () => viewmodel.locateFolder(folders[idx]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
