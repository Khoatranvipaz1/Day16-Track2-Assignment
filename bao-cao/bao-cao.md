# Báo cáo Lab 16 - Cloud AI Environment Setup
**Sinh viên:** TranVanKhoa  
**Ngày:** 18/06/2026  
**Phương án:** CPU Fallback (LightGBM trên r5.large)

---

## 1. Lý do sử dụng CPU thay GPU

Tài khoản AWS mới bị giới hạn quota GPU ở mức 0 vCPU cho dòng G/VT instances. Yêu cầu tăng quota cho `g4dn.xlarge` (cần 4 vCPU) bị từ chối/trì hoãn. Do đó chuyển sang phương án CPU với instance `r5.large` (2 vCPU, 16 GB RAM) — không yêu cầu quota đặc biệt.

---

## 2. Kết quả Benchmark (LightGBM trên r5.large)

| Metric | Kết quả |
|---|---|
| Dataset | Credit Card Fraud Detection (284,807 giao dịch) |
| Instance | r5.large (CPU fallback) |
| Load data time | 2.34 giây |
| Training time | 3.55 giây |
| Best iteration | 4 |
| AUC-ROC | 0.9241 |
| Accuracy | 96.68% |
| F1-Score | 0.085 |
| Precision | 0.045 |
| Recall | 0.898 |
| Inference latency (1 row) | 1.17 ms |
| Inference throughput (1000 rows) | 816,335 rows/giây |

---

## 3. Nhận xét

- **Training time 3.55 giây** trên 227,845 mẫu — LightGBM rất hiệu quả trên CPU nhờ gradient boosting tối ưu.
- **AUC-ROC 0.924** là kết quả tốt cho bài toán fraud detection với dữ liệu mất cân bằng nặng (chỉ 0.17% fraud).
- **Recall 0.898** — mô hình phát hiện được ~90% giao dịch gian lận, phù hợp yêu cầu thực tế.
- **Throughput 816K rows/giây** cho thấy khả năng inference real-time hoàn toàn khả thi trên CPU.
- So với GPU (g4dn.xlarge): GPU sẽ vượt trội hơn khi training deep learning model lớn, nhưng với gradient boosting như LightGBM, CPU r5.large cho kết quả tương đương với chi phí ~$0.19/giờ.

---

## 4. Hạ tầng triển khai

| Thành phần | Loại | Chi phí/giờ |
|---|---|---|
| CPU Node | r5.large | ~$0.126 |
| Bastion Host | t3.micro | ~$0.010 |
| NAT Gateway | — | ~$0.045 |
| Load Balancer | ALB | ~$0.008 |
| **Tổng** | | **~$0.19/giờ** |

**Thời gian deploy:** 12:29 PM — hoàn thành trong ~12 phút.
