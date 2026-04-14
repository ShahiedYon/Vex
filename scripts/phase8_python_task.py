from datetime import datetime

out_file = r"C:\Users\yonsh\Vex\workspace\phase8-python-result.txt"
log_file = r"C:\Users\yonsh\Vex\logs\phase8-python.log"
ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

with open(out_file, "w", encoding="utf-8") as f:
    f.write("Vex Phase 8 Python Result\n")
    f.write(f"Timestamp: {ts}\n")
    f.write("Status: SUCCESS\n")
    f.write("Message: Python handler executed successfully.\n")

with open(log_file, "a", encoding="utf-8") as f:
    f.write(f"[{ts}] Python handler executed successfully\n")

print("Python Phase 8 task complete")