use std::io::{Cursor, Read};

use anyhow::{anyhow, Error};
use flate2::read::GzDecoder;
use flutter_rust_bridge::frb;
use image::GenericImageView;

pub struct ImageInfo {
    pub aspect_ratio: f64,
    pub metadata_string: Option<String>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn extract_metadata(input_bytes: &[u8]) -> Result<ImageInfo, Error> {
    let exif_info = extract_general_info(input_bytes)?;
    let nai_metadata_result = extract_nai_data(input_bytes);
    if nai_metadata_result.is_ok() {
        // Use NAI metadata string first
        return Ok(ImageInfo {
            aspect_ratio: exif_info.aspect_ratio,
            metadata_string: nai_metadata_result.ok(),
        });
    }
    // Or fallback to EXIF metadata
    return Ok(exif_info);
}

#[frb(opaque)]
pub struct DataReader {
    data: Vec<u8>,
    index: usize,
}

impl DataReader {
    pub fn new(data: Vec<u8>) -> DataReader {
        DataReader { data, index: 0 }
    }

    pub fn read_bit(&mut self) -> u8 {
        let bit = self.data[self.index] & 1; // 只读取最低位
        self.index += 1;
        bit
    }

    pub fn read_byte(&mut self) -> u8 {
        let mut byte = 0;
        for i in 0..8 {
            byte |= self.read_bit() << (7 - i);
        }
        byte
    }

    pub fn read_bytes(&mut self, n: usize) -> Vec<u8> {
        (0..n).map(|_| self.read_byte()).collect()
    }

    pub fn read_int32(&mut self) -> i32 {
        let bytes = self.read_bytes(4);
        let bytes4: [u8; 4] = bytes.try_into().unwrap();
        i32::from_be_bytes(bytes4)
    }
}

fn extract_nai_data(input_bytes: &[u8]) -> Result<String, Error> {
    let img = image::load_from_memory(input_bytes)?;
    let (width, height) = img.dimensions();

    let mut lowest_data = vec![];

    for x in 0..width {
        for y in 0..height {
            let pixel = img.get_pixel(x, y);
            let a = pixel[3]; // 获取 alpha 值
            lowest_data.push(a);
        }
    }

    let mut reader = DataReader::new(lowest_data);
    let magic = "stealth_pngcomp";
    let magic_string = String::from_utf8(reader.read_bytes(magic.len()))
        .unwrap_or("Magic number not found".to_string());

    if magic == magic_string {
        let data_length = reader.read_int32() as usize;
        let gzip_bytes = reader.read_bytes(data_length / 8);
        let mut gz = GzDecoder::new(gzip_bytes.as_slice());
        let mut decompressed_data = String::new();
        gz.read_to_string(&mut decompressed_data)?;
        Ok(decompressed_data)
    } else {
        Err(Error::msg("Magic does not match"))
    }
}

fn extract_general_info(input_bytes: &[u8]) -> Result<ImageInfo, Error> {
    // 计算宽高比
    let img = image::load_from_memory(input_bytes)?;
    let (width, height) = img.dimensions();
    if height == 0 {
        return Err(anyhow!("图片高度为零 (Image height is zero)"));
    }
    let aspect_ratio = width as f64 / height as f64;

    // 使用 infer 推断文件类型，选择性地提取元数据
    let kind =
        infer::get(input_bytes).ok_or_else(|| anyhow!("无法识别的文件类型 (Unknown file type)"))?;
    let mime_type = kind.mime_type();

    let metadata_string = match mime_type {
        // 专门处理 PNG，读取文本块
        "image/png" => {
            let decoder = png::Decoder::new(Cursor::new(input_bytes));
            decoder.read_info().ok().and_then(|reader| {
                let info = reader.info();
                info.utf8_text
                    .iter()
                    .find_map(|chunk| chunk.get_text().ok())
                    .or_else(|| {
                        info.uncompressed_latin1_text
                            .iter()
                            .map(|chunk| chunk.text.clone())
                            .next()
                    })
            })
        }

        // 专门处理 JPEG 和 TIFF，读取 EXIF
        "image/jpeg" | "image/tiff" => {
            let mut cursor = Cursor::new(input_bytes);
            exif::Reader::new()
                .read_from_container(&mut cursor)
                .ok()
                .and_then(|exif| {
                    exif.get_field(exif::Tag::ImageDescription, exif::In::PRIMARY)
                        .and_then(|field| Some(field.display_value().to_string()))
                })
        }

        // 其他支持的格式 (WEBP, GIF, BMP 等) 通常没有标准化的文本元数据字段，只返回宽高比
        _ => None,
    };

    Ok(ImageInfo {
        aspect_ratio,
        metadata_string,
    })
}
