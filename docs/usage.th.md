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
git clone https://github.com/prinveee/crewlead.git && cd crewlead
ln -s "$PWD/bin/crewlead" ~/.local/bin/crewlead
```

## 2. ใส่ crewlead ลงโปรเจกต์ (ครั้งเดียวต่อโปรเจกต์)

เลือกกรณีที่ตรงกับคุณ

### A. มีโปรเจกต์อยู่แล้ว

```bash
cd my-project
crewlead init --labels     # คัดลอก flow เข้าโปรเจกต์ และสร้าง label ให้
```

จากนั้นเปิด agent ในโปรเจกต์แล้วรัน skill:

```
/project-setup
```

ขั้นนี้คือตอนที่ crew ทำความรู้จักโปรเจกต์ของคุณ agent จะอ่านโค้ด, README,
เอกสาร, ไฟล์ CI และ commit ล่าสุด แล้วร่างไฟล์สั้น ๆ 4 ไฟล์:

| ไฟล์ | agent ได้รู้อะไร |
|---|---|
| `.ai/steering/product.md` | ผลิตภัณฑ์คืออะไร ใครใช้ และกฎที่ทุกการแก้ต้องเคารพ |
| `.ai/steering/tech.md` | stack และเวอร์ชัน, สิ่งที่ตัดสินใจไว้แล้ว, อะไรห้ามรันบนเครื่อง |
| `.ai/steering/structure.md` | โค้ดอยู่ตรงไหน ของใหม่ควรวางไว้ที่ไหน (พร้อมไฟล์ตัวอย่างจริงให้ลอกแบบ) |
| `.ai/business-rules.md` | business rule ทุกข้อ มีรหัส (`BR-ORDER-01`) และบอกที่มา |

agent จะไม่แต่งกฎขึ้นเอง อะไรที่เดาจะติด `[assumption]` ไว้ และถามคุณทีละไม่เกิน
3 ข้อ จะไม่เขียนไฟล์จนกว่าคุณจะอนุมัติ ไฟล์เหล่านี้ถูกรวมเข้า `AGENTS.md`
ทุก agent จึงได้อ่านก่อนเริ่มงานทุกครั้ง ถ้ารัน `/project-setup` ซ้ำภายหลัง
จะเสนอเฉพาะส่วนที่เปลี่ยนไป

ดูว่ายังขาดอะไรได้ตลอดด้วย:

```bash
crewlead check
```

commit ไฟล์ที่ได้มาใน branch ใหม่แล้วเปิด PR เพื่อนในทีมไม่ต้องติดตั้ง crewlead
เพราะโปรเจกต์มีทุกอย่างครบแล้ว

### B. เริ่มโปรเจกต์ใหม่

ยังไม่มีโค้ดให้อ่าน crew จึงทำความรู้จักโปรเจกต์ด้วยการถามคุณแทน

```bash
mkdir my-app && cd my-app && git init -b main
echo "# my-app" > README.md && git add README.md && git commit -m "Start my-app"
gh repo create my-app --private --source . --push   # หรือสร้างบน GitLab แล้ว push
crewlead init --labels
```

ต้อง commit แรกก่อนรัน `crewlead init` เพราะหลังจากนั้น pre-push hook จะห้าม push
ตรงเข้า `main` และทุกการเปลี่ยนแปลงต้องผ่าน PR

จากนั้นรัน `/project-setup` ใน agent เมื่อยังไม่มีโค้ด agent จะถามแทนการอ่าน:
ผลิตภัณฑ์คืออะไร ใครใช้, business rule ที่คุณรู้อยู่แล้ว, และ stack ที่ตั้งใจจะใช้
แล้วเขียน `product.md`, `tech.md` และ business rules จากคำตอบของคุณ
ส่วนแผนที่โค้ดและคำสั่งต่าง ๆ รอไว้จนกว่าจะมีโค้ด

จากนั้นให้ crew สร้างโครงเริ่มต้นให้ เหมือนงานทั่วไป:

```
/issue-new สร้างแอป Next.js มีหน้า login และตั้งค่าเทสต์ไว้
/issue-plan 1      →  อ่านแผน แล้ว comment /go ใน issue #1
/issue-plan 1 go   →  ได้ draft PR ที่มีโครงโปรเจกต์
```

เมื่อ merge PR นั้นแล้ว รัน `/project-setup` อีกครั้ง คราวนี้ agent จะอ่านโค้ดจริง
แล้วเติมคำสั่ง, ไฟล์เทสต์ และแผนที่โค้ดให้ จากนั้นใช้งานแบบกรณี A ได้เลย

## 3. ใช้งานทุกวัน

ใน Claude Code skill เป็นคำสั่ง slash (`/issue-new`) ส่วน Codex และ Cursor
เรียกด้วยชื่อ skill

| อยากทำอะไร | รันอะไร | เกิดอะไรขึ้น |
|---|---|---|
| ขอของใหม่ | `/issue-new ปุ่ม export ควรมีวันที่ด้วย` | Intake ถามคุณสองสามข้อ แล้วเขียน issue ให้ชัด (หลังคุณตกลง) |
| ให้วางแผน | `/issue-plan 12` | Planner อ่านโค้ด แล้วโพสต์แผนใน issue #12 |
| อนุมัติแผน | comment `/go` ใน issue #12 | comment นี้คือการอนุมัติ และเก็บไว้เป็นหลักฐาน นับเฉพาะ `/go` จากคนที่มีสิทธิ์ write ใน repo |
| ให้ลงมือทำ | `/issue-plan 12 go` | Implementor ทำตามแผนพร้อมเทสต์ แล้วเปิด **draft PR** |
| ให้ตรวจ | `/change-review 34` | Reviewer ที่**เริ่มอ่านใหม่**ตรวจ PR #34 เทียบกับแผน |
| ดูว่ามีอะไรรออยู่ | `/whats-next` | อะไรรอคุณ, AI ทำอะไรอยู่, อะไรอยู่ในคิว |
| รับงาน | คุณ merge PR เอง | agent ไม่ merge เด็ดขาด |

bug เล็ก ๆ ที่คนในทีม (มีสิทธิ์ write) เปิด issue ไม่ต้องรอ `/go`: planner วางแผนแล้ว
implementor ลงมือได้เลย แต่คุณยังเป็นคนตรวจและ merge ส่วน bug ที่คนนอกแจ้ง
ต้องรอ `/go` จากคุณก่อน

## 4. ดูสถานะจาก label

label ของ issue บอกเสมอว่างานอยู่ตรงไหน

| Label | ความหมาย | ใครต้องทำ |
|---|---|---|
| `ai` | อยู่ในคิว | AI |
| `ai:awaiting-approval` | แผนพร้อมให้อ่าน | **คุณ**: `/go` หรือ comment |
| `ai:implementing` | กำลังทำ | AI |
| `ai:in-review` | เปิด draft PR แล้ว CI กับ reviewer กำลังตรวจ | AI |
| `ai:ready` | ตรวจผ่านแล้ว | **คุณ**: merge |
| `ai:blocked` | agent หยุดและมีคำถาม | **คุณ**: ตอบใน issue แล้วสั่ง `/issue-plan <n>` อีกครั้ง |

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
- **คนนอกสั่ง crew ไม่ได้:** บน repo สาธารณะใครก็ comment ได้ agent จึงไม่นับ
  `/go` จากคนที่ไม่มีสิทธิ์ write, ถือว่าข้อความใน issue และ comment เป็นข้อมูล
  ไม่ใช่คำสั่ง และไม่ติด label `allow-*` เอง
- **protected paths:** การแก้ไฟล์กลุ่มนี้ต้องได้ `/go` จากคนใน `approvers`
  ที่ไม่ใช่คนที่กำลังทำงานนั้นอยู่

## 7. ปรับให้เป็นของคุณ

ทุกอย่างทำงานบนเครื่องของคุณ: เป็นไฟล์ใน repo ของคุณ, ใช้ agent และ CI ของคุณ
ไม่มี service และไม่ต้องสมัคร account crewlead กำหนดทิศทางที่ควรเป็น
ส่วนรายละเอียดคุณปรับเองได้

| อยากเปลี่ยน… | แก้ที่ไหน |
|---|---|
| ไฟล์ที่ห้ามแก้เด็ดขาด (เช่น migration) | `immutable_paths` ใน `.ai/project.yml` |
| ไฟล์ที่ต้องให้ lead ตรวจ (auth, payment, deploy…) | `protected_paths` |
| คำสั่ง lint, test, build | `commands` |
| ใครอนุมัติได้, ทำงานคนเดียว | `approvers`, `solo` |
| agent ตัวไหนเล่นบทไหน | `agents` |
| ชื่อ label ให้ตรงกับ board ของคุณ | `labels` |
| ภาษาของ issue, แผน และรีวิว (เช่น `th`) | `language` |
| สิ่งที่ agent ต้องรู้และต้องเคารพ | `.ai/steering/*.md` และไฟล์ business rules |
| กฎเพิ่มสำหรับบางโฟลเดอร์ | วาง `AGENTS.md` ไว้ในโฟลเดอร์นั้น |
| skill ของคุณเอง | `.agents/skills/<ชื่อ>/` (crewlead เก็บไว้ให้ ไม่ลบ) |

guard ใน CI อ่านกฎจาก `.ai/project.yml` ถ้าแก้รายการในไฟล์นั้น สิ่งที่ guard ตรวจก็เปลี่ยนตาม
`crewlead update` เขียนทับเฉพาะไฟล์ของ crewlead เอง (`.ai/flow/`, `AGENTS.md`
ที่สร้างให้, skill และ template ของ crewlead) ทุกอย่างในตารางข้างบนคงอยู่เหมือนเดิม

## 8. อัปเดต

```bash
cd my-project
crewlead update
```

ไฟล์ของคุณเอง (`.ai/project.yml`, steering, business rules) จะไม่ถูกเขียนทับ
