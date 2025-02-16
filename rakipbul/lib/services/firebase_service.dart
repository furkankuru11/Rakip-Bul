import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;



class  FirebaseService {
  FirebaseService();
  static  FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService();
  
  static Future<String> getApiKey() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "rakipbul-c86d3",
      "private_key_id": "1fa1b5764b812f4a889bb631804dcdfe32773542",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDAACRB8dxibH8t\nyXnLLMIkhJqgobuKN5F8FWB2Vh5o4pjaq76SFLmK2U1Tzdq1R/uvwK0K7rF2/R7R\nVIH0RE6hq1r4GTF9biJbn88FqzyNE3qYd7K9aJxherARkXSH7M/cXWYQW2I/NyJu\nC1SEOnEFYlTmW6r/fUPBuY97ZMGRB99ogRdiUs+Z1AjLq6YXLsknA24/OBuxki9Y\n2IeueXmFaBEVGtirSPOK5qKARz8B3+YtCm1o21xcBUDdVTeteAp6tGRk/YSDRhHZ\nP/j+eJFLrfzLtPNwjxNi78LqWJHixghVkaFI920MMjguMj2X1ngmNNqtly1UF8SE\nqCb84ZiLAgMBAAECggEATxs/1RPLk5nURI8waS/FxboE443/cRE4FgHQvrD40ooa\nJG6ClDmJwNWLcK3uIKbJ4j3mjgyOfdIIcoL5ECVcqGurjXED3QQVj96mM1W8Gvwd\nlNgsgrGpTNh51qMxehduBQNOXArqzdTvkJuGdPyHOIqtJEQ8jguUcSr9HQAEaLY3\n+ArVn9JClTwy+qwiRfrff2zaBe5wtN6BFyWJrNHJZcKfHvRtRmb7qp2YcgyoxtW3\nEZCtkroAudACNz4GjeMfJ9UAkopKNJ1F80aiVbBkZyptGFZoqasmf8VXYNrkfhdw\nrdlAuNvfN/xkAmYtGMGLqR6h5RmjawHYi7rZ2+InkQKBgQD2TbH0NeaHX8yD9nIo\ncvMR6FQE251fYVorfJo8mOJC3n8M+2q1qgSwNYqoSdI4ttLzR2i9ZP+UfIBcvN4T\nqIRC/+EsJXwbOn7PdO1NCkFUOy4LsgW2Vb6yDMF+TlTRTjFWmnC5K9pFd5oJ22FJ\nPbfNOesihGQzsxfTQtErjvaT/QKBgQDHjyspN07ZlzyqhS1iZIfQQJjVbLOba+3b\nV8DCjsdzGxGMJ06FPKbcywqt257r+rSvBX1KHw2sfo/LMxB8GLt0GMX7ED7BGwxL\nA6HlkzhzgdzyHfSg5hCQQfz53HGG49c99VwxrvrB8qXB6awxXIpw84JxV5CGyqV2\nS6YL19ZRJwKBgHuORjLnxxkp6YJZYrL/1weosF0vfiaWw5EFFKpJV1eMHdf5V3KC\nM4/hjAkX3yksLW506An6XGu0eQAMjqr14kNp8R8gPr25/ls7oL8A4fzLIzIiv9LT\n+LGAzJ/703ib7QwwtVNuuDQY52ECeC8xkr6Uy2upVkrJEK6d2igrs25RAoGBALYW\nTaSrAbiLReC16iZoYoBEIPBE4lGDlqJYnNsp2pWN8mH3D6+FGyBF6DWhOo5J0QoO\nMTcrxJdLWDtqGbWR/6E8ZZHjTc93tazQ4K2QuqayrP8DFE6n/h8TBxiZ68DQLnsr\nYXc4GThVBqg8ZlEYBn5vwutWodpMF9QrzJPr2nNrAoGANNiWL8QXxgB12In0+eIL\nt0pHcoLT6qynOERSUqx+2Sop4BTdNMPabnQB3amvH4NYRNZ2L6hSvJmF8SZxGw/f\nsCe2HOMK2vCAE/okuD49asJ2dOvlxlkwsvA5JoWCtf62W64OXbCK64BdkuDW7AAE\np+jA9u/uvZIO549R8wf6tHg=\n-----END PRIVATE KEY-----\n",
      "client_email": "firebase-adminsdk-2dlm0@rakipbul-c86d3.iam.gserviceaccount.com",
      "client_id": "115748698356696946614",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-2dlm0%40rakipbul-c86d3.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };
    
    final scopes = [
      "https://www.googleapis.com/auth/firebase.messaging",
    ];
    
    final client = await auth.clientViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson), scopes);
    final credentials = await auth.obtainAccessCredentialsViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson), scopes, client);
    client.close();
    return credentials.accessToken.data;
  }

  Future<void> getDeviceToken() async {
    final apiKey = await getApiKey();
    final token = await FirebaseMessaging.instance.getToken(vapidKey: apiKey);
    print(token);
  }
}
