[English](methodology.md) · **ภาษาไทย**

# crewlead — วิธีทำงานแบบ AI agent (ภาพรวมทั้งหมด)

เอกสารนี้สรุปทุกอย่างที่ตกลงกันไว้ ส่วนกฎที่ agent ต้องทำตามอยู่ที่ `core/AGENTS.core.md` (ทุก session) และ `core/rules.md` (เมื่อเล่นบทใน flow)
(ภาษาอังกฤษ) ถ้าเอกสารนี้ขัดกับไฟล์กฎ ให้ยึดไฟล์กฎ แล้วแก้เอกสารนี้ตาม

## 1. หลักใหญ่

- **GitHub หรือ GitLab เป็นแหล่งข้อมูลจริงที่เดียว**: issue และ board เก็บสถานะ, comment แผนเก็บวิธีทำ, PR/MR เก็บผลงาน
- **Spec-Driven แบบเบาสำหรับงานเล็ก** และ **BMAD แบบเต็มสำหรับงานใหญ่ที่คนเป็นผู้นำ**
- **คนทำกับคนตรวจต้องแยกกัน**: ค่าตั้งต้นคือ Claude วางแผนและตรวจ, Codex ลงมือทำ, CI ตัดสินผล, คนอนุมัติ
  เปลี่ยนได้ที่ `agents` ใน `.ai/project.yml` (ใช้ agent ตัวเดียวทุกบทบาทก็ได้ แต่ต้องแยก session และ reviewer ต้องเริ่ม context ใหม่เสมอ)
- **กฎสำคัญต้องบังคับด้วยระบบ** (CI, guard, hook, deny rules) ไม่ใช่แค่เขียนไว้ใน prompt
- **agent ไม่จำอะไรข้ามรอบ** ทุกรอบเริ่มใหม่และอ่านสถานะจาก GitHub ทำให้ทำต่อจากจุดที่ค้างได้เสมอ

## 2. ทุกงานเข้ามาทางไหน

| ทาง | ใช้เมื่อ | คนนำหรือ AI |
|---|---|---|
| **Intake** (`issue-new`) | คำขอใหม่ เช่น feature หรือ bug ที่ยังไม่ชัด | คนคุยกับ Intake agent |
| **Issue form** | bug ที่ชัดอยู่แล้ว หรือจดเร็วๆ จากมือถือ | คน (planner จะตรวจ DoR ให้อีกที) |
| **BMAD** | งานใหญ่ (size L) | คนวางแผนโดยมี AI ช่วย แล้วแตกเป็น story และ issue |

## 3. งานแต่ละแบบ (Lanes)

| Lane | Spec | ความอิสระ |
|---|---|---|
| Bug | เขียนเทสต์ที่ทำให้ bug เกิดซ้ำก่อน (ต้อง fail) | A3: ทำเองจนได้ draft PR |
| Feature S/M | mini-spec ใน issue | A2: ต้องรอ `/go` |
| Story (BMAD) | AC จาก story file | A2: ต้องรอ `/go` |
| Large | — | A1: วิเคราะห์อย่างเดียว แล้วคนวางแผนด้วย BMAD |

ถ้าแตะ **protected path** ไม่ว่างานแบบไหน ความอิสระสูงสุดคือ A2 และต้องติด `needs-lead-review`
ส่วน A4 (merge เอง) **ไม่อนุญาตเด็ดขาด**

**การอนุมัติ** (เรียบง่าย แต่ย้อนตรวจได้):
- อนุมัติ = คอมเมนต์ `/go` บน issue หลังแผนล่าสุด และลิงก์คอมเมนต์นั้นอยู่ใน PR ส่วนการพิมพ์ "yes" หรือ "go" ในแชตไม่นับเป็นการอนุมัติ ใช้ได้แค่อนุญาตให้ push, โพสต์ หรือเปิด PR
- งานที่**ไม่แตะ** protected path: ใครก็ `/go` ได้ รวมถึง dev ที่ทำงานนั้นเอง
- งานที่**แตะ** protected path: ต้องเป็นคนใน `approvers` (`.ai/project.yml`) ที่**ไม่ใช่** dev ที่ทำงานนั้น และ**ไม่ใช่**คนเปิด issue ทั้งตอน `/go` และตอน approve PR ก่อน merge ถ้าไม่มีใครเข้าเงื่อนไข agent จะหยุดถาม

## 4. ใครทำหน้าที่อะไร

| หน้าที่ | ใคร | ที่ไหน |
|---|---|---|
| Stakeholder | เจ้าของธุรกิจ | ส่งคำขอผ่านคุณ |
| PM / Lead / QA | **คุณ** | อนุมัติ issue, อนุมัติแผน (`/go`), merge |
| Setup | agent ไหนก็ได้ | `project-setup` ครั้งแรกหลัง install หรือเมื่อโค้ดเปลี่ยนไปมาก |
| Intake (SA/PM) | `agents.planner` (ค่าตั้งต้น Claude) | `issue-new` บนเครื่อง |
| Planner | `agents.planner` (ค่าตั้งต้น Claude) | `issue-plan <n>` |
| Implementor | `agents.implementor` (ค่าตั้งต้น **Codex**) | session ของตัวเองใน worktree ของ issue นั้น |
| Reviewer | `agents.reviewer` (ค่าตั้งต้น Claude) เริ่ม context ใหม่เสมอ (Claude ใช้ subagent, Cursor/Codex เปิดแชตใหม่) | `change-review <pr>` |
| Tester | CI | GitHub Actions |

**ใช้ได้ทุก agent**: กฎอยู่ใน `AGENTS.md` และ skill (`project-setup`, `issue-new`, `issue-plan`, `change-review`, `whats-next`) อยู่ที่ `.agents/skills/` ที่เดียว
ส่วน `.claude/skills/` เป็น link ไปที่เดียวกัน Claude Code เรียกด้วย `/issue-plan 12`,
Cursor ใช้ `/issue-plan 12`, Codex ใช้ `$issue-plan 12` (ตารางเต็มอยู่ใน `AGENTS.md` §10)

**Subagent** ใช้แค่ 2 จุด: planner แตกไปค้นโค้ดได้ไม่เกิน 3 ตัวเมื่องานต้องค้นกว้าง และ reviewer รันเป็น subagent เพื่อให้เริ่ม context ใหม่
**Multi-agent** เป็นการส่งงานต่อกันเป็นลำดับ ไม่ใช่กลุ่ม agent ที่คุยกันเอง ข้อมูลจริงทั้งหมดอยู่บน issue/PR ส่วนการส่งต่องาน
เป็นแค่ข้อความสั้นๆ ว่า "ไปดูที่ไหน" ตั้งได้ด้วย `handoff` ใน `.ai/project.yml`:
`auto` (ค่าตั้งต้น: ใช้ Herdr ถ้ามี ไม่มีก็ให้คนก๊อปวาง), `herdr` หรือ `manual` (agent พิมพ์ข้อความให้คนเอาไปวางใน agent ตัวถัดไป)
**Herdr ไม่จำเป็นต้องมี** ข้อความหายไปก็เสียแค่การก๊อปวางใหม่ ไม่เสียงาน
**ทำงานพร้อมกันได้เฉพาะคนละ issue** เพราะแต่ละ issue มี worktree และ branch ของตัวเอง

## 5. ขั้นตอน

```
① INTAKE     คุณ + Intake agent → Issue (ผ่าน DoR) → [label: ai]
② PLAN       Planner: research → Implementation Plan (comment)
             ├ Bug S, ไม่แตะส่วนสำคัญ → ③ ทันที
             ├ อื่นๆ → ai:awaiting-approval → คุณตรวจ → /go → ③
             └ ใหญ่หรือกำกวม → ai:blocked → คุณตัดสิน
③ IMPLEMENT  implementor ใน worktree ai/<n>-<slug>, ทำทีละ step (เทสต์ fail ก่อน)
             แผนผิด → หยุดแล้วรายงาน planner (ห้ามเดาเอง) → Plan v2
             → draft PR (Closes #n) → ai:in-review
④ VERIFY     CI + guard (บังคับ) · CI ไม่ผ่าน → implementor แก้ ≤3 รอบ → ไม่ไหว → ai:blocked
⑤ REVIEW     Reviewer (context ใหม่): ครบ AC? ตรงแผน? เทสต์ไม่ถูกทำให้อ่อนลง? ปลอดภัย?
             มีปัญหา → implementor แก้ ≤2 รอบ · ผ่าน → ai:ready
⑥ ACCEPT     คุณลองใช้แล้ว merge → issue ปิดเอง
⑦ LEARN      PR ไหนพลาด → เพิ่มกฎใน steering หรือ guard
```

## 6. ด่านตรวจ

- **DoR** (ก่อนวางแผน): เป้าหมายชัด, AC เทสต์ได้และระบุ business rule ที่เกี่ยวข้อง (`AC-1 [BR-PRICE-01]: …`), มีขอบเขตว่าไม่ทำอะไร, ระบุขนาดแล้ว, ไม่มีคำถามค้าง
- **AC → test**: AC ทุกข้อต้องมีเทสต์ที่ระบุชื่อ และต้องอยู่ทั้งในแผนและใน PR
- **DoD** (ก่อน merge): AC ทุกข้อมีเทสต์ที่ผ่าน, ถ้าเป็น bug ต้องมีเทสต์ที่เคย fail, CI ผ่าน, review ผ่าน, เอกสารอัปเดตแล้ว

**ดีไซน์ (งาน UI)**: `project-setup` ถามข้อเดียวว่า "มีดีไซน์ของตัวเอง (Figma ฯลฯ) ที่ UI ต้องตามไหม"
- **ไม่มี** (`design: none`): agent ออกแบบหน้าจอเองได้ โดยใช้ component และรูปแบบที่โค้ดมีอยู่แล้ว reviewer สรุปสิ่งที่ออกแบบเองให้คนดู
- **มี** (`design: figma` + ลิงก์): **ถ้ามีดีไซน์ ต้องเคารพ ถ้าไม่มี ไม่เป็นไร**
  - หน้าหรือ state ที่มี frame: แนบลิงก์ใน issue, ทำตาม frame, reviewer เทียบแล้วรายงานจุดที่ต่าง,
    เปลี่ยนหน้าตาที่ดีไซน์กำหนดไว้ต้องให้ designer คอมเมนต์อนุมัติ
  - หน้าหรือ state ที่ไม่มี frame: agent ออกแบบเองจาก UI ที่มีอยู่และ frame ที่ใกล้เคียง แล้วสรุปให้ designer ดู งานไม่ติด

## 7. สิ่งที่ระบบบังคับจริง

| กฎ | บังคับด้วย |
|---|---|
| ห้ามแก้ไฟล์ใน immutable path (เช่น migration ที่ commit แล้ว) | guard ใน CI (ยกเว้นด้วย label `allow-immutable-edit`) |
| ห้ามเพิ่ม `.skip` หรือ `.only` | guard (`allow-test-skip`) |
| จำนวนเทสต์ต้องไม่ลดลง | guard (`allow-test-removal`) |
| แตะส่วนสำคัญต้องให้ lead ตรวจ | guard ติด label `needs-lead-review` ให้เอง (ค่าเริ่มต้นรวมไฟล์กฎของทุก agent: `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `.cursor/`, `.codex/`, `.github/`, `.ai/`) |
| guard แก้กฎตัวเองไม่ได้ | ใช้ script และ config จาก branch ฐานของ PR |
| ห้าม push ขึ้น main และห้าม force push | git pre-push hook (ใช้ได้กับทุก agent) |
| ห้าม merge, ห้ามข้าม hook | deny rules ใน `.claude/settings.json` (เฉพาะ Claude ส่วน agent อื่นมี hook กับ guard คุมอยู่) |
| เอกสารไม่ชี้ไปไฟล์ที่ย้ายหรือลบแล้ว | `.ai/flow/check-drift.sh` (reviewer รันเมื่อ PR ย้ายหรือเปลี่ยนชื่อไฟล์) |
| ห้าม deploy ถ้า CI ไม่ผ่าน | อยู่ใน workflow deploy ของแต่ละโปรเจกต์ |

GitHub Free ไม่มี branch protection สำหรับ repo private จึงต้องบังคับบนเครื่องแทน
ถ้าวันหน้าใช้ GitHub Pro ให้เปิด branch protection เพิ่มอีกชั้น

## 8. Steering (ความรู้ของโปรเจกต์ ใช้แนวคิดจาก Kiro)

| ไฟล์ | เนื้อหา |
|---|---|
| `.ai/steering/product.md` | ผู้ใช้, ขอบเขตและสิ่งที่ไม่ทำ, **หลักการธุรกิจที่ห้ามละเมิด**, คำศัพท์ |
| `.ai/steering/tech.md` | Stack, **การตัดสินใจทางเทคนิคที่ห้ามขัด** (ADR), กฎของเครื่องและการ deploy |
| `.ai/steering/structure.md` | แผนที่โค้ด, ของใหม่ต้องวางไว้ที่ไหน, pattern ที่ควรเลียนแบบ, convention |
| ไฟล์ business rules (`business_rules` ใน `.ai/project.yml`) | กฎธุรกิจฉบับเต็ม ทุกข้อมี ID (`BR-<AREA>-<nn>`), จุดที่โค้ดยังผิดกฎ, คำถามที่ยังไม่มีใครตัดสิน |

**Business rules**: `product.md` สรุปเฉพาะกฎที่ทุกงานต้องเคารพ ส่วนฉบับเต็มอยู่ในไฟล์ business rules
งานที่ทำให้โค้ด**ผิด**กฎคือ bug งานที่**เปลี่ยน**กฎคือ feature และ PR นั้นต้องแก้ไฟล์กฎ (พร้อม ID) ใน PR เดียวกัน

- `crewlead` รวม steering ทั้งหมดเข้า `AGENTS.md` ทุก agent จึงได้อ่านทุกครั้ง
- แต่ละไฟล์ยาวไม่เกินประมาณหนึ่งหน้า เป็น**บทสรุป**ที่ลิงก์ไปเอกสารเต็ม
- ถ้าโปรเจกต์มี BMAD และ**ข้อมูลไม่ตรงกัน ให้ยึดเอกสาร BMAD** แล้วแก้ steering ใน PR เดียวกัน
- PR ที่เปลี่ยนพฤติกรรม การตัดสินใจ หรือโครงสร้างโค้ด ต้องอัปเดต steering ด้วย (reviewer ตรวจข้อนี้)
- กฎที่ใช้แค่ในโฟลเดอร์เดียว ให้วาง `AGENTS.md` ไว้ในโฟลเดอร์นั้น (เทียบกับ `fileMatch` ของ Kiro)

เทียบกับ spec ของแต่ละงานใน Kiro: **requirements = issue body** และ **design + tasks = plan comment**
(ส่วน Design มีเฉพาะ Feature M และ Story)

## 9. ใช้กับ BMAD ยังไง

- story file เป็น spec ส่วน issue เป็นสถานะ ใน story ให้ใช้ `Tracking: #n` แทน `Status:`
- epic เป็น issue แม่ และ story เป็น sub-issue ติด label `bmad`
- ถ้า story ใหญ่เกินไป แตกเป็น sub-issue ได้ แต่ทุกใบต้องอ้างเลข AC ของ story
  issue แม่ปิดได้เมื่อ AC ทุกข้อมีเทสต์ที่ผ่านแล้ว

## 10. ติดตั้งลงโปรเจกต์

ครั้งแรกบนเครื่อง ทำ link ให้เรียก `crewlead` ได้จากทุกที่:

```bash
ln -s "$PWD/bin/crewlead" ~/.local/bin/crewlead     # รันจากในโฟลเดอร์ crewlead
```

จากนั้นในโปรเจกต์ไหนก็ได้:

```bash
cd <repo>
crewlead init      # ติดตั้ง (ใส่ --labels เพื่อสร้าง label, --platform github|gitlab ถ้าอ่านเองไม่ออก)
crewlead update    # อัปเดตเป็นเวอร์ชันล่าสุดของ crewlead
crewlead check     # ดูอย่างเดียว: ติดตั้งเวอร์ชันไหน, ยังขาดอะไร, มี drift ไหม
```

`crewlead init` **คัดลอก**ไฟล์เข้าไปในโปรเจกต์ ไม่ได้เอา crewlead ทั้ง repo ไปใส่
หลังติดตั้ง โปรเจกต์ทำงานได้ด้วยตัวเอง เพื่อนในทีมไม่ต้องมี crewlead
ต้นฉบับมีที่เดียวบนเครื่องคุณ ถ้าแก้ต้นฉบับ ให้รัน `crewlead update` ในโปรเจกต์นั้น

**แพลตฟอร์ม (GitHub / GitLab)**: installer อ่านก่อน จาก `platform` ใน `.ai/project.yml` → host ของ remote → ไฟล์ CI ใน repo
ถ้าอ่านไม่ออกจะถามว่าใช้อะไร (หรือสั่งเองด้วย `--platform gitlab`) บน GitLab จะได้ template ใน `.gitlab/`
และไฟล์ guard สำหรับ `include:` ใน `.gitlab-ci.yml` (installer ไม่แก้ CI ของทีม แค่บอกบรรทัดที่ต้องเพิ่ม)
agent ใช้ `glab` ตามตารางใน `AGENTS.md` §11 และอนุมัติด้วย `/go`, `go` หรือ `APPROVED`
**label**: ถ้า board ของทีมมี label สถานะอยู่แล้ว (เช่น `Currently reviewing`) ตั้งชื่อแทนได้ใน `project.yml` → `labels`
แล้ว installer จะไม่สร้างหรือแก้ label นั้น (`project-setup` อ่าน label ที่มีอยู่แล้วเสนอให้)

ติดตั้งมี 2 ขั้น:

1. **`crewlead init`** (สคริปต์) ตรวจสิ่งที่รู้ได้แน่นอนจาก repo แล้วเขียน `.ai/project.yml` ให้ครั้งแรก:
   default branch, ชนิดโปรเจกต์ (Frappe / Node / Python), คำสั่ง lint/test/build, ไฟล์เทสต์,
   โฟลเดอร์ migration/patches (immutable), ไฟล์เสี่ยง (protected) และ business rules ที่มีอยู่แล้ว
   ส่วนที่หาไม่เจอจะปล่อยว่าง ไม่เดา ไฟล์ที่ crewlead ไม่ได้สร้างจะไม่ถูกเขียนทับ
2. **`project-setup`** (skill ใช้ได้ทุก agent) อ่านโค้ด, README, เอกสาร และ CLAUDE.md/AGENTS.md เดิม
   แล้วร่าง `structure.md`, `tech.md`, `product.md`, ไฟล์ business rules และตรวจ `project.yml`
   จุดที่เดามาจะติด `[assumption]` ให้คุณยืนยัน (ถามรอบละไม่เกิน 3 ข้อ) แล้วรัน `crewlead update` ให้เอง
   business rules ที่ไม่มีเอกสารรองรับจะไม่ถูกแต่งขึ้น แต่จะถูกเขียนไว้เป็นคำถามที่ยังเปิดอยู่

| ไฟล์ | เจ้าของ |
|---|---|
| `.ai/flow/**`, `AGENTS.md`, skill ใน `.agents/skills/` และ link ใน `.claude/skills/`, issue/PR templates, `ai-guard.yml` | crewlead (เขียนทับทุกครั้งที่ `crewlead update`) |
| `.ai/project.yml`, `.ai/steering/*.md`, ไฟล์ business rules | โปรเจกต์ (install ไม่แตะ) |
| `.claude/settings.json` | โปรเจกต์ (install แค่เพิ่ม deny rules กลาง) |
| `.claude/settings.local.json` | ของคุณบนเครื่องนี้ ไม่อยู่ใน git: deny rules เฉพาะเครื่อง เช่น ห้ามแตะ DB ที่ใช้ร่วมกัน |
| pre-push hook | อยู่ในแต่ละ clone ไม่อยู่ใน git ต้องรัน `crewlead update` ในทุก clone |
