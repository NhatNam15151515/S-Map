---
name: ui-ux
description: |
  Quy tac va pattern cho UI/UX design decisions trong du an S-Map Flutter.
  Bao gom cach dung UI/UX Pro Max Skill de chon mau, font, layout, map style.
  Trigger khi: tao widget moi, chon mau sac, chon font, thiet ke map style,
  quyet dinh layout moi, chon icon, thiet ke bat ky UI component nao.
---

# UI/UX Skill - S-Map

## QUY TAC SO 1: Luon query UI/UX Pro Max Skill TRUOC

Truoc khi tu dat bat ky mau, font, spacing, hay style nao, BAT BUOC chay:

```bash
python "c:\Nhat Nam\intern flutter\S-map\.ai-tools\ui-ux-pro-max-skill\src\ui-ux-pro-max\scripts\search.py" "<query mo ta>" --stack flutter --domain <domain>
```

Domains co san:
- style    : Chon tong the visual style, widget style
- color    : Chon mau sac, palette
- typography: Chon font, font weight, text size
- ux       : UX pattern, interaction design
- icons    : Chon icon set, icon style
- chart    : Bieu do, stats visualization

---

## He thong mau sac - Chi dung AppColors

```dart
// Dung AppColors tu commons/utils/app_colors.dart
AppColors.millionGrey    // Text mau toi (900)
AppColors.argent         // Text mau xam (800)
AppColors.doveGrey       // Text mau xam (6c)
AppColors.white
AppColors.grey

// KHONG dung:
Color(0xFF123456)        // Inline hex
Colors.blue              // Flutter built-in (tru Colors.transparent)
color.withOpacity(0.5)   // Deprecated -> dung withAlpha()
```

---

## He thong Text Style - Dung AppTextTheme

```dart
// Dung AppTextTheme extension tren Color
someColor.textTheme.textStyle
someColor.textTheme.boldStyle
someColor.textTheme.subTitleStyle
someColor.textTheme.textTitleStyle

// Lay style tu AppStyle
final style = AppStyle.of(context);
style.blackTextColor.textTheme.boldStyle.copyWith(fontSize: 16)

// KHONG dung:
TextStyle(color: Color(0xFF...), fontWeight: FontWeight.bold)
```

---

## Font - Montserrat DUY NHAT

```dart
// Dung AppFontWeight enum
AppFontWeight.thin.weight       // 100
AppFontWeight.extraLight.weight // 200
AppFontWeight.light.weight      // 300
AppFontWeight.regular.weight    // 400
AppFontWeight.medium.weight     // 500
AppFontWeight.semiBold.weight   // 600
AppFontWeight.bold.weight       // 700
AppFontWeight.extraBold.weight  // 800
AppFontWeight.black.weight      // 900

// KHONG import font khac
// KHONG dung FontWeight.w700 truc tiep
```

---

## Button Style - Dung AppStyle

```dart
final style = AppStyle.of(context);
style.buttonStyle                              // Elevated button (secondary bg)
style.outlineButtonStyle                       // Outline button (primary border)
style.textButtonStyle                          // Text button (no bg)
style.whiteButton                             // White elevated button
style.buttonStyle.mergeBackgroundColor(AppColors.xxx)  // Override mau nen
style.buttonStyle.mergeOutlineColor(AppColors.xxx)     // Override border
```

---

## Map Style (MapLibre) - Gan Google Maps

### Bat buoc query truoc:
```bash
python "..." "map style google maps offline vector tiles" --stack flutter --domain style
python "..." "map color palette roads water landuse labels" --domain color
```

### Palette tham chieu Google Maps-like:
| Layer              | Mau     |
|--------------------|---------|
| Background / Land  | #F2EFE9 |
| Road fill (local)  | #FFFFFF |
| Road fill (major)  | #E8E4DA |
| Road casing        | #C7B99A |
| Water              | #A8D8EA |
| Park / Greenery    | #C8DEBA |
| Building           | #E0DEDA |
| Label text         | #666666 |
| Label halo         | #FFFFFF |

### Font glyph:
- Dung Montserrat (da co trong assets/fonts/)
- Phai ho tro Latin Extended Additional (tieng Viet co dau day du)

---

## Widget Styling Rules

```dart
// Lay theme dung cach
final style = AppStyle.of(context);
style.colorScheme.primary
style.colorScheme.secondary
style.buttonStyle
style.blackTextColor
style.greysTextColor[0]   // index 0=900, 4=50

// Widget API dung (khong deprecated)
WidgetStateProperty.all(...)   // KHONG MaterialStateProperty
CardThemeData(...)             // KHONG CardTheme trong ThemeData
color.withAlpha(51)            // KHONG withOpacity(0.2)
```

---

## Anti-patterns CAM

| # | Sai                                     | Dung                                  |
|---|-----------------------------------------|---------------------------------------|
| 1 | Tu dat mau map ma khong query UI/UX tool| Chay UI/UX Pro Max Skill truoc        |
| 2 | Color(0xFF...) inline trong widget      | Dung AppColors.xxx                    |
| 3 | TextStyle() inline                      | Dung AppTextTheme system              |
| 4 | withOpacity()                           | Dung withAlpha()                      |
| 5 | MaterialStateProperty                   | Dung WidgetStateProperty              |
| 6 | Import font khac ngoai Montserrat       | Montserrat la font duy nhat           |
| 7 | Hard-code map palette                   | Dung palette Google Maps-like + tool  |
| 8 | FontWeight.w700 truc tiep               | Dung AppFontWeight.bold.weight        |

