from datetime import datetime

log_file = r"C:\Users\yonsh\Vex\logs\python-test.log"

with open(log_file, "a", encoding="utf-8") as f:
    f.write(f"[{datetime.now()}] Python tool executed successfully\n")

print("Python test complete")
