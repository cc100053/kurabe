class AuthErrorMapper {
  static String message(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('password') &&
        (msg.contains('6') || msg.contains('least'))) {
      return 'パスワードは6文字以上で入力してください。';
    }
    if (msg.contains('same_password') ||
        (msg.contains('password') &&
            msg.contains('different') &&
            msg.contains('old'))) {
      return '新しいパスワードは、現在のパスワードと異なるものを設定してください。';
    }
    if (msg.contains('weak') && msg.contains('password')) {
      return 'パスワードが弱すぎます。より強力なパスワードを設定してください。';
    }
    if (msg.contains('invalid') && msg.contains('password')) {
      return 'パスワードが正しくありません。';
    }
    if (msg.contains('invalid') &&
        (msg.contains('login') || msg.contains('credentials'))) {
      return 'メールアドレスまたはパスワードが正しくありません。';
    }

    if (msg.contains('invalid') && msg.contains('email')) {
      return 'メールアドレスの形式が正しくありません。';
    }
    if ((msg.contains('email') || msg.contains('user')) &&
        msg.contains('already') &&
        (msg.contains('registered') || msg.contains('exists'))) {
      return 'このメールアドレスは既に登録されています。';
    }
    if (msg.contains('email') &&
        msg.contains('not') &&
        msg.contains('confirmed')) {
      return 'メールアドレスが確認されていません。受信箱を確認してください。';
    }

    if (msg.contains('identity') &&
        (msg.contains('exists') || msg.contains('linked'))) {
      return 'このアカウントは既に別のユーザーに紐づいています。';
    }
    if (msg.contains('not') && msg.contains('found')) {
      return 'アカウントが見つかりません。';
    }

    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('socket')) {
      return 'ネットワーク接続に問題があります。接続を確認してください。';
    }

    if (msg.contains('rate') && msg.contains('limit')) {
      return 'リクエストが多すぎます。しばらく待ってから再試行してください。';
    }

    return '予期せぬエラーが発生しました。もう一度お試しください。';
  }
}
