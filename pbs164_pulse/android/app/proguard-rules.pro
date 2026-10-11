# libabpartool.so, JNI_OnLoad içinde bu sınıfı adıyla kaydeder; yeniden adlandırılmamalı/silinmemeli.
-keep class com.bluetrum.abpartool.** { *; }
-keepclasseswithmembernames class * { native <methods>; }
