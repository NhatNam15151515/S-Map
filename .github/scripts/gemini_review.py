import os
import json
import urllib.request
from google import genai

def main():
    gemini_api_key = os.environ.get("GEMINI_API_KEY")
    github_token = os.environ.get("GITHUB_TOKEN")
    repo = os.environ.get("GITHUB_REPOSITORY")
    pr_number = os.environ.get("PR_NUMBER")
    
    if not gemini_api_key:
        print("GEMINI_API_KEY is not set. Skipping Gemini review.")
        return
        
    diff_file = "pr_diff.patch"
    if not os.path.exists(diff_file):
        print("Diff file not found. Skipping.")
        return

    with open(diff_file, "r", encoding="utf-8", errors="ignore") as f:
        diff_text = f.read()

    if not diff_text.strip():
        print("Empty diff. Skipping Gemini review.")
        return

    if len(diff_text) > 30000:
        diff_text = diff_text[:30000] + "\n... (diff truncated)"

    prompt = f"""Bạn là Senior Flutter & Dart Code Reviewer chuyên nghiệp. Hãy review Pull Request diff dưới đây cho dự án S-Map (Offline Motorbike Map Flutter App).

YÊU CẦU FORMAT PHẢN HỒI (bằng tiếng Việt):

## 🤖 Gemini AI Code Review

### Kết luận
Chọn 1 trong: PASS | PASS_WITH_NOTES | NEEDS_CHANGES | REJECT
(Kèm giải thích ngắn gọn lý do)

### Findings
Liệt kê chi tiết các vấn đề (nếu có):
- [Mức độ: Critical/High/Medium/Low] `file_path:line` - Mô tả vấn đề.
  **Gợi ý fix:**
  ```dart
  // Code gợi ý sửa cụ thể ở đây
  ```
(Nếu code tốt không có lỗi, ghi: "Không phát hiện lỗi nghiêm trọng.")

### Test nên chạy
Liệt kê các unit test / integration test cụ thể cần chạy.

### Ghi chú scope
Nhận xét ngắn gọn về scope của PR.

---
DƯỚI ĐÂY LÀ DIFF CỦA PULL REQUEST:
```diff
{diff_text}
```
"""

    client = genai.Client(api_key=gemini_api_key)
    
    review_comment = None

    # Try Interactions API first (newest), then fallback to generate_content
    models_to_try = ["gemini-3.6-flash", "gemini-3.5-flash"]
    
    for model_name in models_to_try:
        # Try Interactions API
        try:
            print(f"Trying Interactions API with model: {model_name}...")
            interaction = client.interactions.create(
                model=model_name,
                input=prompt,
            )
            review_comment = interaction.output_text
            print(f"Successfully generated review using Interactions API: {model_name}")
            break
        except Exception as e:
            print(f"Interactions API error for {model_name}: {e}")
        
        # Fallback to generate_content
        try:
            print(f"Trying generate_content with model: {model_name}...")
            response = client.models.generate_content(
                model=model_name,
                contents=prompt,
            )
            review_comment = response.text
            print(f"Successfully generated review using generate_content: {model_name}")
            break
        except Exception as e:
            print(f"generate_content error for {model_name}: {e}")

    if not review_comment:
        print("Failed to get review from all models. Exiting.")
        return

    # Post comment to GitHub PR
    gh_url = f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments"
    gh_headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json"
    }
    gh_payload = {"body": review_comment}
    gh_req = urllib.request.Request(gh_url, data=json.dumps(gh_payload).encode("utf-8"), headers=gh_headers)

    try:
        with urllib.request.urlopen(gh_req) as response:
            print(f"Successfully posted Gemini review comment to PR #{pr_number}")
    except Exception as e:
        print(f"Error posting comment to GitHub PR: {e}")

if __name__ == "__main__":
    main()
