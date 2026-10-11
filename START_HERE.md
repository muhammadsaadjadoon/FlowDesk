# Flow Desk — sab se pehle ye parho

App ka naam **Flow Desk** hai. Tumhara provided logo assets mein hai aur UI navy/teal/mint theme follow karti hai.

## Pehle bina Firebase app try karo

1. ZIP extract karo. Source folder kholo jahan `pubspec.yaml` hai.
2. Android Studio mein emulator start karo.
3. PowerShell us source folder mein kholo:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\bootstrap.ps1
flutter devices
flutter run --dart-define=DEMO=true
```

Agar multiple devices hon to Android emulator choose karo. Demo sample accounts/tasks ke saath chalta hai. App ke upper toolbar ya Account screen mein role switch karke intern/admin workflows try karo. Demo edits isi device par save hote hain, doosre phone par sync nahi hote.

Bootstrap native Android/iOS/web files banata hai, dependencies install karta hai aur checks chalata hai. Kisi command mein failure aaye to usi output ko resolve karo; aage pass hone ka assume mat karo.

## Internship ke required live database ke liye

Firebase ka naya project banao, Email/Password Authentication enable karo aur Firestore production mode mein create karo. README ke FlutterFire commands se connect karo, phir supplied rules deploy karo.

Live app run command:

```powershell
flutter run
```

`DEMO=true` hata do. Naya account pending intern hoga. First admin ka `users/UID` document Firebase Console mein manually `role: admin`, `active: true` set karna hai. Admin baqi interns ko Reports mein approve kar sakta hai. App se self-admin banana allowed nahi hai.

Is app ko Gemini key, Python backend ya separate Firebase Storage bucket ki zaroorat nahi. Profile photo size limit ke saath Firestore mein save hoti hai. Firebase account/project setup tumhari taraf se karna zaroori hai; mere paas tumhare new project ka access nahi.

## Check commands

```powershell
.\scripts\verify.ps1
```

Live Firebase rules ke tests aur two-account verification README mein hain. Delivery mein kya actually pass hua, `VERIFICATION.md` mein clearly likha hai.
