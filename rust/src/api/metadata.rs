use std::io::{Cursor, Read};

use anyhow::{anyhow, Error};
use flate2::read::GzDecoder;
use flutter_rust_bridge::frb;
use image::GenericImageView;

#[flutter_rust_bridge::frb(sync)]
pub fn extract_metadata(input_bytes: &[u8]) -> Result<String, Error> {
    let nai_data_result = extract_nai_data(input_bytes);
    if nai_data_result.is_ok() {
        return nai_data_result;
    }
    let exif_data_result = extract_exif(input_bytes);
    return exif_data_result;
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
            lowest_data.push(a & 1);
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

fn extract_exif(input_bytes: &[u8]) -> Result<String, Error> {
    // 使用 infer 判断文件类型
    let kind =
        infer::get(input_bytes).ok_or_else(|| anyhow!("无法识别的文件类型 (Unknown file type)"))?;

    let mime_type = kind.mime_type();

    match mime_type {
        // 专门处理 PNG 文件
        "image/png" => {
            let decoder = png::Decoder::new(Cursor::new(input_bytes));
            let reader = decoder.read_info()?;

            // 只检查 iTXt 和 tEXt，读取第一个找到的
            let info = reader.info();
            for itxt_chunk in &info.utf8_text {
                return Ok(itxt_chunk.get_text()?);
            }
            for text_chunk in &info.uncompressed_latin1_text {
                return Ok(text_chunk.text.clone());
            }
            Err(anyhow!("iTXt or tEXt chunk not found"))
        }

        // 其他不支持的类型 (JPG, TIFF, AVIF, etc.)
        _ => Err(anyhow!(
            "不支持的文件类型 (Unsupported file type): {}",
            mime_type
        )),
    }
}
