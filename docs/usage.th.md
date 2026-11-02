# วิธีใช้ crewlead

คู่มือสั้น ๆ ใช้งานได้ทันที ถ้าอยากอ่านวิธีคิดทั้งหมด ดู
[`methodology.th.md`](methodology.th.md)

## ภาพรวมในรูปเดียว

```
 คุณ                  AI crew                                  คุณ
 ───                  ───────                                  ───
 "อยากได้ X"  ─►  Intake เขียน issue
                  Planner เขียนแผน           ─►  /go  (คุณอนุมัติแผน)
                  Implementor ลงมือทำ เปิด draft PR
                  CI + guard ตรวจ
                  Reviewer (ตาใหม่) ตรวจซ้ำ               ─►  คุณ merge
```

คุณเป็นคนบอกว่า**จะทำอะไร** และเป็นคน **merge** ส่วนที่เหลือ agent ทำให้
ทุกขั้นถูกเขียนไว้ใน issue หรือ PR งานจึงไม่หาย

## 1. ติดตั้ง (ครั้งเดียวต่อเครื่อง)

ต้องมี: git, bash, jq, `gh` (GitHub) หรือ `glab` (GitLab) ที่ login แล้ว
และ coding agent อย่างน้อยหนึ่งตัว (Claude Code, Codex CLI หรือ Cursor)

```bash
git clone https://github.com/anotherpart/crewlead.git && cd crewlead
ln -s "$PWD/bin/crewlead" ~/.local/bin/crewlead
```

## 2. ใส่ crewlead ลงโปรเจกต์ (ครั้งเดียวต่อโปรเจกต์)

```bash
cd my-project
crewlead init --labels     # คัดลอก flow เข้าโปรเจกต์ และสร้าง label ให้
```

จากนั้นเปิด agent ในโปรเจกต์แล้วรัน skill:

```
/project-setup
```

agent จะอ่านโค้ดและเอกสาร ร่างสิ่งที่ agent ต้องรู้ (ตัวผลิตภัณฑ์, เทคโนโลยี,
โค้ดอยู่ตรงไหน, business rules) แล้วถามให้คุณยืนยัน ดูว่ายังขาดอะไรได้ตลอดด้วย:

```bash
crewlead check
```

commit ไฟล์ที่ได้มา เพื่อนในทีมไม่ต้องติดตั้ง crewlead เพราะโปรเจกต์มีทุกอย่างครบแล้ว

## 3. ใช้งานทุกวัน

ใน Claude Code skill เป็นคำสั่ง slash (`/issue-new`) ส่วน Codex และ Cursor
เรียกด้วยชื่อ skill

| อยากทำอะไร | รันอะไร | เกิดอะไรขึ้น |
|---|---|---|
| ขอของใหม่ | `/issue-new ปุ่ม export ควรมีวันที่ด้วย` | Intake ถามคุณสองสามข้อ แล้วเขียน issue ให้ชัด (หลังคุณตกลง) |
| ให้วางแผน | `/issue-plan 12` | Planner อ่านโค้ด แล้วโพสต์แผนใน issue #12 |
| อนุมัติแผน | comment `/go` ใน issue #12 | comment นี้คือการอนุมัติ และเก็บไว้เป็นหลักฐาน |
| ให้ลงมือทำ | `/issue-plan 12 go` | Implementor ทำตามแผนพร้อมเทสต์ แล้วเปิด **draft PR** |
| ให้ตรวจ | `/change-review 34` | Reviewer ที่**เริ่มอ่านใหม่**ตรวจ PR #34 เทียบกับแผน |
| ดูว่ามีอะไรรออยู่ | `/whats-next` | อะไรรอคุณ, AI ทำอะไรอยู่, อะไรอยู่ในคิว |
| รับงาน | คุณ merge PR เอง | agent ไม่ merge เด็ดขาด |

bug เล็ก ๆ ไม่ต้องรอ `/go`: planner วางแผนแล้ว implementor ลงมือได้เลย
แต่คุณยังเป็นคนตรวจและ merge

## 4. ดูสถานะจาก label

label ของ issue บอกเสมอว่างานอยู่ตรงไหน

| Label | ความหมาย | ใครต้องทำ |
|---|---|---|
| `ai` | อยู่ในคิว | AI |
| `ai:awaiting-approval` | แผนพร้อมให้อ่าน | **คุณ**: `/go` หรือ comment |
| `ai:implementing` | กำลังทำ | AI |
| `ai:in-review` | เปิด draft PR แล้ว CI กับ reviewer กำลังตรวจ | AI |
| `ai:ready` | ตรวจผ่านแล้ว | **คุณ**: merge |
| `ai:blocked` | agent หยุดและมีคำถาม | **คุณ**: ตอบใน issue |

## 5. เลือก crew ของคุณ

ใน `.ai/project.yml` บอกว่า agent ตัวไหนเล่นบทไหน

```yaml
agents:
  planner: claude
  implementor: codex
  reviewer: claude

solo: true        # ทำคนเดียว? ให้อนุมัติงานตัวเองได้
```

ถ้า reviewer เป็นคนละ agent กับ implementor จะเจอปัญหาได้มากกว่า

## 6. ตาข่ายกันพลาด (เปิดไว้แล้ว)

- **pre-push hook:** ห้าม push ตรงเข้า branch หลัก และห้าม force push
- **guard job ใน CI:** PR จะไม่ผ่านถ้าเทสต์ถูกลบหรือถูก skip หรือมีการแก้
  migration ที่ commit ไปแล้ว ยกเว้นคนติด label `allow-*` ให้
- **protected paths:** การแก้ไฟล์กลุ่มนี้ต้องได้ `/go` จากคนใน `approvers`
  ที่ไม่ใช่คนที่กำลังทำงานนั้นอยู่

## 7. อัปเดต

```bash
cd my-project
crewlead update
```

ไฟล์ของคุณเอง (`.ai/project.yml`, steering, business rules) จะไม่ถูกเขียนทับ
