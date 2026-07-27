<p align="center">
  <img src="https://github.com/user-attachments/assets/cadce527-ec65-4ee6-9579-c47ca7cfcca1" alt="Cell" width="120">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Cell-r277-ff8800?style=for-the-badge&logo=appveyor">
  <img src="https://img.shields.io/badge/WotLK-3.3.5a-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/status-stable-brightgreen?style=for-the-badge">
</p>

<h1 align="center">Cell — WotLK 3.3.5a backport</h1>

<p align="center">
  <b>Clean raid frame addon with customizable frames for World of Warcraft 3.3.5a (WotLK).</b><br>
  <i>Backport of Cell r277 to the WoW 3.3.5a client.</i>
</p>

<p align="center">
  <a href="#english">English</a> ·
  <a href="#russian">Русский</a>
</p>

---

<a name="english"></a>
## English

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#credits">Credits</a>
</p>

### About

**Cell** is a clean, powerful raid frame addon inspired by CompactRaid, Grid2,
Aptechka, and VuhDo: solo/party/raid frames, aura indicators, click-castings,
raid debuffs tracking, spell request utilities, and more. This repository is a
**backport of Cell r277** to the **WoW 3.3.5a (WotLK)** client.

<img width="178" height="299" alt="party" src="https://github.com/user-attachments/assets/396180df-9d33-483b-8eae-41d09efab515" />

<a name="features"></a>
### Features

#### Layouts

<img width="470" height="441" alt="layout" src="https://github.com/user-attachments/assets/507fd502-ef18-4d37-9c0e-b1dd5d5a1575" />

Fully customizable party and raid frames — size, position, orientation, group
arrangement, and power bars. Auto-switch layouts by spec/role with independent
settings for solo, party, raid, arena, and battleground.

#### Appearance

<img width="470" height="491" alt="appearance" src="https://github.com/user-attachments/assets/1a662292-ca2c-48a9-9e56-a2315507b3d3" />

Textures, colors, alphas, and fonts are all in your hands. Health color by
class or by percentage, customizable background, out-of-range dimming, and full
control over the look of every frame.

#### Indicators

<img width="480" height="441" alt="indicators" src="https://github.com/user-attachments/assets/9c1273be-dc68-40f8-ae17-b53245a5509a" />

Dozens of built-in indicators (health text, aggro bar, shield bar, heal
prediction, dispels, raid icons, and more) plus unlimited custom indicators for
any buff or debuff — icons, bars, rects, texts, colors, and glows.

#### Click-Castings

<img width="399" height="441" alt="click-castings" src="https://github.com/user-attachments/assets/4d7b33d5-f2f2-4666-a5c7-388cef15a672" />

Bind spells, macros, and items directly to mouse clicks on unit frames —
mouseover healing without target switching. Supports keyboard and multi-button
mice, with per-class and per-spec binding profiles.

#### Raid Debuffs

<img width="470" height="441" alt="raiddebuffs" src="https://github.com/user-attachments/assets/dea8a922-1be3-4ddb-890b-03eeba76d6c8" />

Track boss abilities and dangerous debuffs in dungeons and raids with
prioritized, per-instance debuff lists and glow effects. Ships with data for
Classic, TBC, and WotLK instances, fully editable in-game.

#### Utilities

Useful raid tools: ready check, countdown, spell/dispel requests, death report,
marks bar, and hiding of default Blizzard party/raid frames.

#### Spotlight Frame

Extra 15 unit buttons that can be set to Target, Focus, Unit, Tank, and more —
keep the most important units always in sight.

<a name="slash-commands"></a>
### Slash Commands

Use `/cell` for more information.

| Command | Description |
| --- | --- |
| `/cell` | Show all available commands |
| `/cell opt` | Open the options frame |

<a name="installation"></a>
### Installation

1. Download the latest release (or clone this repository).
2. Extract the archive.
3. Move the **Cell** folder into:
   ```
   \Interface\AddOns\
   ```
4. Enable it on the character-select AddOns screen and launch the game. Type `/cell` to open options.

### Compatibility

- Built and tested on **Warmane** (WoW 3.3.5a, Interface `30300`).
- Developed exclusively for **Warmane**. I am not responsible for functionality on other servers.

<a name="credits"></a>
### Credits

- Original addon: [enderneko/Cell](https://github.com/enderneko/Cell) — A World of Warcraft raid frame addon
- WotLK 3.3.5a backport: **Keoo**

---

<a name="russian"></a>
## Русский

<p align="center">
  <a href="#возможности">Возможности</a> ·
  <a href="#установка">Установка</a> ·
  <a href="#благодарности">Благодарности</a>
</p>

### Об аддоне

**Cell** — это аккуратный и мощный аддон рейдовых рамок, вдохновлённый
CompactRaid, Grid2, Aptechka и VuhDo: рамки соло/группы/рейда, индикаторы аур,
клик-касты, отслеживание рейдовых дебаффов, запросы заклинаний и многое другое.
Этот репозиторий — **бэкпорт Cell r277** под клиент **WoW 3.3.5a (WotLK)**.

<img width="178" height="299" alt="party" src="https://github.com/user-attachments/assets/396180df-9d33-483b-8eae-41d09efab515" />

<a name="возможности"></a>
### Возможности

#### Макеты (Layouts)

<img width="470" height="441" alt="layout" src="https://github.com/user-attachments/assets/507fd502-ef18-4d37-9c0e-b1dd5d5a1575" />

Полностью настраиваемые рамки группы и рейда — размер, позиция, ориентация,
расположение групп и полосы ресурсов. Автопереключение макетов по спеку/роли с
независимыми настройками для соло, группы, рейда, арены и поля боя.

#### Внешний вид (Appearance)

<img width="470" height="491" alt="appearance" src="https://github.com/user-attachments/assets/1a662292-ca2c-48a9-9e56-a2315507b3d3" />

Текстуры, цвета, прозрачность и шрифты — всё в ваших руках. Цвет здоровья по
классу или по проценту, настраиваемый фон, затемнение вне дистанции и полный
контроль над видом каждой рамки.

#### Индикаторы (Indicators)

<img width="480" height="441" alt="indicators" src="https://github.com/user-attachments/assets/9c1273be-dc68-40f8-ae17-b53245a5509a" />

Десятки встроенных индикаторов (текст здоровья, полоса агро, полоса щита,
предсказание лечения, диспелы, рейдовые метки и др.) плюс неограниченные
пользовательские индикаторы для любых баффов и дебаффов — иконки, полосы,
прямоугольники, тексты, цвета и свечения.

#### Клик-касты (Click-Castings)

<img width="399" height="441" alt="click-castings" src="https://github.com/user-attachments/assets/4d7b33d5-f2f2-4666-a5c7-388cef15a672" />

Привязывайте заклинания, макросы и предметы напрямую к кликам мыши по рамкам —
лечение по наведению без смены цели. Поддержка клавиатуры и многокнопочных
мышей, профили привязок для каждого класса и спека.

#### Рейдовые дебаффы (Raid Debuffs)

<img width="470" height="441" alt="raiddebuffs" src="https://github.com/user-attachments/assets/dea8a922-1be3-4ddb-890b-03eeba76d6c8" />

Отслеживайте способности боссов и опасные дебаффы в подземельях и рейдах с
приоритетными списками по каждой локации и эффектами свечения. В комплекте
данные для Classic, TBC и WotLK, полностью редактируемые прямо в игре.

#### Утилиты (Utilities)

Полезные рейдовые инструменты: проверка готовности, отсчёт, запросы
заклинаний/диспела, отчёт о смерти, панель меток и скрытие стандартных рамок
Blizzard.

#### Рамка Spotlight

Дополнительные 15 кнопок юнитов, которые можно настроить на Цель, Фокус, Юнита,
Танка и другое — держите самых важных юнитов всегда на виду.

<a name="команды"></a>
### Команды (Slash Commands)

Введите `/cell` для дополнительной информации.

| Команда | Описание |
| --- | --- |
| `/cell` | Показать все доступные команды |
| `/cell opt` | Открыть окно настроек |

<a name="установка"></a>
### Установка

1. Скачайте последний релиз (или клонируйте репозиторий).
2. Распакуйте архив.
3. Переместите папку **Cell** в:
   ```
   \Interface\AddOns\
   ```
4. Включите аддон на экране выбора персонажа и запустите игру. Введите `/cell`, чтобы открыть настройки.

### Совместимость

- Собрано и протестировано на **Warmane** (WoW 3.3.5a, Interface `30300`).
- Разрабатывалось исключительно для **Warmane**. За работоспособность на других серверах ответственности не несу.

<a name="благодарности"></a>
### Благодарности

- Оригинальный аддон: [enderneko/Cell](https://github.com/enderneko/Cell) — A World of Warcraft raid frame addon
- Бэкпорт под WotLK 3.3.5a: **Keoo**
