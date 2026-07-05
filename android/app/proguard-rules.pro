# flutter_local_notifications persiste agendamentos serializando com GSON 2.8.9,
# que não embute regras de R8 (só a partir do 2.10). Sem estes keeps, o R8 full
# mode remove as assinaturas genéricas dos TypeToken e as notificações agendadas
# quebram em release ("Missing type parameter") — só no build da loja.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }
