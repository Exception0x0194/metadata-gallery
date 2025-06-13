use crate::api::metadata::extract_metadata;
use crate::frb_generated::StreamSink;
use anyhow::Error;
use rayon::prelude::*;
use std::collections::HashMap;
use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};
use std::{
    fs::File,
    io::Read,
    sync::atomic::{AtomicU32, Ordering},
};

#[derive(Debug, Clone)]
pub struct ScanProgress {
    pub total_to_process: u32,
    pub processed: u32,
    pub image_scan_results: Option<Vec<ImageScanResult>>,
    pub folder_scan_result: Option<FolderScanResult>,
}

#[derive(Debug, Clone)]
pub struct ImageScanResult {
    pub file_path: String,
    pub file_last_modified: u64,
    pub metadata_text: String,
}

#[derive(Debug, Clone)]
pub struct FolderScanResult {
    pub folder_path: String,
    pub scan_timestamp: u64,
    pub total_image_count: u32,
}

// 处理单个图片的函数，保存缩略图并返回处理结果
fn process_single_image(image_path: &str) -> Result<ImageScanResult, Error> {
    // 读取文件内容
    let mut file = File::open(image_path)?;
    let mut file_bytes = vec![];
    file.read_to_end(&mut file_bytes)?;

    let modified_time = file.metadata()?.modified()?;
    let file_last_modified = modified_time.duration_since(UNIX_EPOCH)?.as_secs();

    // 提取数据
    let metadata_text = extract_metadata(&file_bytes)?;

    Ok(ImageScanResult {
        file_path: image_path.to_string(),
        file_last_modified: file_last_modified,
        metadata_text: metadata_text,
    })
}

#[flutter_rust_bridge::frb]
pub fn scan_folder(
    sink: StreamSink<ScanProgress>,
    folder_path: String,
    existing_images: HashMap<String, u64>,
) -> Result<(), Error> {
    // 递归查找文件夹下的所有文件
    let all_files_in_folder: Vec<String> = walkdir::WalkDir::new(&folder_path)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| e.file_type().is_file())
        .map(|e| e.path().to_str().unwrap_or_default().to_string())
        .collect();

    // 根据 Dart 传来的已有文件信息，筛选出需要重新处理的文件
    let images_to_process: Vec<String> = all_files_in_folder
        .par_iter() // 使用并行迭代器提高过滤效率
        .filter(|path| {
            if let Ok(metadata) = fs::metadata(path) {
                if let Ok(modified_time) = metadata.modified() {
                    let modified_secs = modified_time
                        .duration_since(UNIX_EPOCH)
                        .map(|d| d.as_secs())
                        .unwrap_or(0);
                    match existing_images.get(*path) {
                        Some(db_modified_time) if *db_modified_time == modified_secs => false, // 存在且未修改，跳过
                        _ => true, // 不存在或已修改，需要处理
                    }
                } else {
                    true
                } // 无法获取修改时间，默认处理
            } else {
                true
            } // 无法获取元数据，默认处理
        })
        .cloned() // 将 &String 转换为 String
        .collect();

    // 发送初始进度
    let total_to_process = images_to_process.len() as u32;
    let processed_count = AtomicU32::new(0);
    sink.add(ScanProgress {
        total_to_process: total_to_process,
        processed: 0,
        image_scan_results: None,
        folder_scan_result: None,
    })
    .unwrap();

    if total_to_process == 0 {
        // 如果没有文件需要处理，也发送一个最终报告
        // 这很重要，因为 Dart 端需要知道这个文件夹已经处理完了
        let folder_result = FolderScanResult {
            folder_path,
            total_image_count: all_files_in_folder.len() as u32, // 总数还是需要报告的
            scan_timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
        };
        sink.add(ScanProgress {
            total_to_process: 0,
            processed: 0,
            image_scan_results: Some(vec![]), // 返回一个空的 Vec
            folder_scan_result: Some(folder_result),
        })
        .unwrap();
        return Ok(());
    }

    // 并行处理所有需要更新的图片
    let processing_results: Vec<ImageScanResult> = images_to_process
        .par_iter()
        .filter_map(|path| {
            let process_result = process_single_image(path);
            // 每处理完一个，就原子性地增加计数器并发送进度
            let count = processed_count.fetch_add(1, Ordering::SeqCst) + 1;
            let _ = sink.add(ScanProgress {
                total_to_process,
                processed: count,
                image_scan_results: None,
                folder_scan_result: None,
            });
            process_result.ok()
        })
        .collect();

    // 所有图片处理完毕，构建最终的文件夹扫描结果
    let folder_result = FolderScanResult {
        folder_path: folder_path,
        total_image_count: all_files_in_folder.len() as u32, // 文件夹内图片总数
        scan_timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
    };

    // 发送包含所有扫描数据的最终消息
    sink.add(ScanProgress {
        total_to_process,
        processed: total_to_process,
        image_scan_results: Some(processing_results),
        folder_scan_result: Some(folder_result),
    })
    .unwrap();

    Ok(())
}
