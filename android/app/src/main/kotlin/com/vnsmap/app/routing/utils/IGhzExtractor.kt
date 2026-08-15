package com.vnsmap.app.routing.utils

import java.io.IOException

interface IGhzExtractor {
    /**
     * Giải nén file .ghz vào thư mục đích.
     *
     * @param ghzPath Đường dẫn tới file .ghz nguồn.
     * @param targetFolderPath Thư mục đích nhận dữ liệu giải nén.
     * @param overwrite Nếu false và thư mục đích đã giải nén hoàn chỉnh (có marker), bỏ qua giải nén.
     * @return true nếu giải nén thành công hoặc dữ liệu hợp lệ đã có sẵn.
     * @throws IOException khi gặp lỗi đọc/ghi file.
     * @throws SecurityException khi entry trong archive chứa đường dẫn thoát ra ngoài thư mục đích (Zip Slip).
     */
    @Throws(IOException::class, SecurityException::class)
    fun extract(ghzPath: String, targetFolderPath: String, overwrite: Boolean = false): Boolean
}
