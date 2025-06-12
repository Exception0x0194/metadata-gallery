use crate::api::metadata::extract_metadata;
use crate::frb_generated::StreamSink;
use anyhow::Error;
use rayon::prelude::*;
use rusqlite::Connection;
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use std::{
    fs::File,
    io::Read,
    sync::atomic::{AtomicU32, Ordering},
};

pub struct ScanProgress {
    pub total: u32,
    pub processed: u32,
}

#[flutter_rust_bridge::frb(sync)]
#[derive(Debug)]

struct ProcessingResult {
    file_path: String,
    file_last_modified: u64,
    metadata_text: String,
}

// 处理单个图片的函数，保存缩略图并返回处理结果
fn process_and_save_single_image(
    image_path: &str,
    _thumbnail_path: &str,
) -> Result<ProcessingResult, Error> {
    // 读取文件内容
    let mut file = File::open(image_path)?;
    let mut file_bytes = vec![];
    file.read_to_end(&mut file_bytes)?;

    let modified_time = file.metadata()?.modified()?;
    let file_last_modified = modified_time.duration_since(UNIX_EPOCH)?.as_secs();

    // 提取数据
    let metadata_text = extract_metadata(&file_bytes)?;

    Ok(ProcessingResult {
        file_path: image_path.to_string(),
        file_last_modified: file_last_modified,
        metadata_text: metadata_text,
    })
}

// 由 Dart 调用的主函数

#[flutter_rust_bridge::frb(sync)]

pub fn scan_folders(
    sink: StreamSink<ScanProgress>,
    folders: Vec<String>,
    db_path: String,
    thumbnail_dir: String,
) {
    std::thread::spawn(move || {
        let mut conn = Connection::open(&db_path).expect("无法打开数据库");

        // 从数据库预加载现有图片信息
        let mut existing_images = HashMap::<String, u64>::new();

        {
            let mut stmt = conn
                .prepare("SELECT file_path, last_modified FROM images")
                .unwrap();
            let rows = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .unwrap();
            for row in rows {
                if let Ok((path, modified)) = row {
                    existing_images.insert(path, modified);
                }
            }
        }

        // 递归展开文件夹，并进行过滤
        let all_image_paths: Vec<String> = folders
            .iter()
            .flat_map(|folder| {
                walkdir::WalkDir::new(folder)
                    .into_iter()
                    .filter_map(Result::ok)
                    .filter(|e| e.file_type().is_file())
            })
            .map(|e| e.path().to_str().unwrap_or_default().to_string())
            .collect();

        let images_to_process: Vec<String> = all_image_paths
            .into_iter()
            .filter(|path| {
                // 获取文件的元数据和最后修改时间 (Unix apoch)
                if let Ok(metadata) = std::fs::metadata(path) {
                    if let Ok(modified_time) = metadata.modified() {
                        let modified_secs = modified_time
                            .duration_since(SystemTime::UNIX_EPOCH)
                            .map(|d| d.as_secs())
                            .unwrap_or(0);

                        // 检查文件是否存在于数据库以及修改时间是否匹配
                        match existing_images.get(path) {
                            Some(db_modified_time) if *db_modified_time == modified_secs => {
                                false // 路径存在且修改时间相同，跳过
                            }
                            _ => true, // 路径不存在或修改时间不同，需要处理
                        }
                    } else {
                        true // 无法获取修改时间，默认处理
                    }
                } else {
                    true // 无法读取元数据，默认处理
                }
            })
            .collect();

        //  并行处理筛选后的图片
        let total_files = images_to_process.len() as u32;
        if total_files == 0 {
            // 如果没有文件需要处理，也发送一个完成状态
            let _ = sink.add(ScanProgress {
                total: 0,
                processed: 0,
            });
            return;
        }

        let processed_count = AtomicU32::new(0);
        let _ = sink.add(ScanProgress {
            total: total_files,
            processed: 0,
        });

        let processing_results: Vec<ProcessingResult> = images_to_process
            .par_iter()
            .filter_map(|path| {
                // process_and_save_single_image 函数现在应该返回包含 last_modified 的结果
                let result = process_and_save_single_image(path, &thumbnail_dir);
                if result.is_err() {
                    println!("Error processing image: {}", result.as_ref().unwrap_err());
                }
                let count = processed_count.fetch_add(1, Ordering::SeqCst) + 1;
                let _ = sink.add(ScanProgress {
                    total: total_files,
                    processed: count,
                });
                return result.ok();
            })
            .collect();

        // 写入或更新数据库

        let tx = conn.transaction().unwrap();
        {
            // 确保 file_path 是主键或具有 UNIQUE 约束
            let mut stmt = tx.prepare("INSERT OR REPLACE INTO images (file_path, metadata_text, last_modified) VALUES (?1, ?2, ?3)").unwrap();
            for result in processing_results {
                stmt.execute((
                    &result.file_path,
                    &result.metadata_text,
                    &result.file_last_modified,
                ))
                .unwrap();
            }
        }

        tx.commit().unwrap();
        conn.close().unwrap();
    });
}

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
