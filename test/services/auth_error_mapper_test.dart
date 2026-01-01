import 'package:flutter_test/flutter_test.dart';
import 'package:kurabe/services/auth_error_mapper.dart';

void main() {
  group('AuthErrorMapper.message', () {
    group('password errors', () {
      test('maps password length error', () {
        final message = AuthErrorMapper.message('Password must be at least 6 characters');
        expect(message, 'パスワードは6文字以上で入力してください。');
      });

      test('maps weak password error', () {
        final message = AuthErrorMapper.message('Password is too weak');
        expect(message, 'パスワードが弱すぎます。より強力なパスワードを設定してください。');
      });

      test('maps invalid password error', () {
        final message = AuthErrorMapper.message('Invalid password provided');
        expect(message, 'パスワードが正しくありません。');
      });
    });

    group('email errors', () {
      test('maps invalid email error', () {
        final message = AuthErrorMapper.message('Invalid email format');
        expect(message, 'メールアドレスの形式が正しくありません。');
      });

      test('maps email already registered error', () {
        final message = AuthErrorMapper.message('User already registered with this email');
        expect(message, 'このメールアドレスは既に登録されています。');
      });

      test('maps email not confirmed error', () {
        final message = AuthErrorMapper.message('Email not confirmed yet');
        expect(message, 'メールアドレスが確認されていません。受信箱を確認してください。');
      });
    });

    group('login errors', () {
      test('maps invalid login credentials error', () {
        final message = AuthErrorMapper.message('Invalid login credentials');
        expect(message, 'メールアドレスまたはパスワードが正しくありません。');
      });
    });

    group('network errors', () {
      test('maps network error', () {
        final message = AuthErrorMapper.message('Network connection failed');
        expect(message, 'ネットワーク接続に問題があります。接続を確認してください。');
      });

      test('maps timeout error', () {
        final message = AuthErrorMapper.message('Connection timeout');
        expect(message, 'ネットワーク接続に問題があります。接続を確認してください。');
      });

      test('maps socket error', () {
        final message = AuthErrorMapper.message('Socket exception');
        expect(message, 'ネットワーク接続に問題があります。接続を確認してください。');
      });
    });

    group('other errors', () {
      test('maps rate limit error', () {
        final message = AuthErrorMapper.message('Rate limit exceeded');
        expect(message, 'リクエストが多すぎます。しばらく待ってから再試行してください。');
      });

      test('maps not found error', () {
        final message = AuthErrorMapper.message('User not found');
        expect(message, 'アカウントが見つかりません。');
      });

      test('returns fallback for unknown error', () {
        final message = AuthErrorMapper.message('Some random error xyz123');
        expect(message, '予期せぬエラーが発生しました。もう一度お試しください。');
      });
    });
  });
}
