# اعتمادات الأصول والتراخيص

هذا الملف يوثق الأصول الخارجية التي تم إدخالها وربطها فعليًا في نسخة **Magic Carpet Knight** الحالية. الأصول كلها مجانية ومختارة من مصادر تسمح بالاستخدام التجاري وإعادة التوزيع وفق بيانات المصدر المتاحة.

## نماذج Quaternius — CC0 1.0

- **Knight Character** — فارس ثلاثي الأبعاد بصيغة FBX/OBJ، ويُستخدم كنموذج اللاعب داخل `scripts/magic_carpet_game.gd`.
  - المصدر الرسمي: [Quaternius Knight Character](https://quaternius.com/packs/knightcharacter.html)
  - الترخيص: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  - الملفات: `assets/models/quaternius/knight/KnightCharacter.fbx`، ونسخة OBJ الاحتياطية.

- **Ultimate Monsters — Flying Demon** — وحش طائر ثلاثي الأبعاد يُستخدم كعقبة جوية.
  - المصدر الرسمي: [Quaternius Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html)
  - الترخيص: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  - الملفات: `assets/models/quaternius/monsters/FlyingDemon.fbx` و`Atlas_Monsters.png`.

- **Ultimate Modular Ruins** — عناصر أقواس وأطلال وأعلام حجرية تُستخدم كعقبات ومعالم بعيدة.
  - المصدر الرسمي: [Quaternius Ultimate Modular Ruins](https://quaternius.com/packs/ultimatemodularruins.html)
  - الترخيص: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  - الملفات: `assets/models/quaternius/ruins/Arch_Gothic_RoundColumn.fbx`، `Wall_ArchRound.fbx`، `Flag_GothicArch.fbx`.

- **Ultimate Nature Pack** — نماذج الصخور المتنوعة.
  - المصدر الرسمي: [Quaternius Ultimate Nature](https://quaternius.com/packs/ultimatenature.html)
  - الترخيص: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  - الملفات: `assets/models/catalog/rocks/FBX__Rock_1.fbx`، `FBX__Rock_4.fbx`، `FBX__Rock_Moss_2.fbx`.

## أصول CC0 من مكتبة الألعاب

- **Game Ready Gate Asset Pack** — بوابة حجرية مفصلة بخامات base color/normal/metallic، وتُستخدم كعقبة رئيسية.
  - صفحة المصدر: [Oxygen3D — Game Ready Gate Asset Pack](https://oxygen3d.itch.io/game-ready-gate-asset-pack)
  - الترخيص المنشور في بيانات الكتالوج: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  - الملفات: `assets/models/catalog/gate/gate.glb` وخاماته المرافقة.

- **Floating Fungi: Low-Poly Mushroom Islands Asset Pack** — جزيرة طائرة تستخدم كمعلم بيئي بعيد.
  - صفحة المصدر: [Dumivid — Floating Fungi](https://dumivid.itch.io/floating-fungi-low-poly-mushroom-islands-asset-pack)
  - الترخيص المنشور في بيانات الكتالوج: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  - الملف: `assets/models/catalog/island/fbx/island_small.fbx`.

- **Furniture Asset Pack 3D - Free** — نموذج سجادة OBJ حقيقي، استخدم في البساط السحري مع دوران ومقياس مناسبين للعبة.
  - صفحة المصدر: [Ladoncha — Furniture Asset Pack](https://ladoncha.itch.io/furniture-asset-pack)
  - الترخيص المنشور في بيانات الكتالوج: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  - الملفات: `assets/models/catalog/rug/rug.obj` و`rug.mtl`.

## أصول من إنشائنا داخل المشروع

- `assets/audio/collect.wav` و`assets/audio/impact.wav`: مؤثران صوتيان قصيران مولدان محليًا بصيغة PCM عبر سكربت Python بسيط، ولا يعتمدان على مكتبة خارجية.
- خامات البساط والزخارف الطرفية، الجوهرة الإجرائية، الجسيمات، الإضاءة، السحب وخطوط المسار: عناصر Godot إجرائية مساندة. لا تُستخدم هذه العناصر كبديل عن نماذج العقبات أو الفارس أو السجادة الحقيقية؛ النماذج الرئيسية أعلاه مستوردة ومرتبطة فعليًا بالمشهد عبر `scripts/magic_carpet_game.gd`.
- `assets/fonts/NotoSansArabic-wght.ttf`: خط Noto Sans Arabic من Google Fonts، مرخص تحت OFL-1.1، مع نسخة الترخيص في `assets/fonts/NotoSansArabic-OFL.txt`.

## ملاحظة التحقق

تُحمّل النماذج من مسارات `res://` داخل دالة `_load_model`، وتُستخدم في إنشاء اللاعب والعقبات والمعالم الخلفية. تم حذف ملفات GLB غير المتوافقة مع مستورد Godot من مسار الجواهر/البلورات بدل الادعاء باستخدامها؛ البلورات الحالية مؤثرات التقاط إجرائية خفيفة، بينما عقبات اللعب نفسها تستخدم نماذج 3D فعلية موثقة أعلاه.
