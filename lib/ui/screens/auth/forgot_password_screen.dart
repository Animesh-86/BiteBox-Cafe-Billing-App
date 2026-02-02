import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
     final email = _emailController.text.trim();
     if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an email')));
        return;
     }

     setState(() => _isLoading = true);
     try {
       await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
       if (mounted) {
         showDialog(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Email Sent'),
            content: Text('Password reset link sent to $email'),
            actions: [
              TextButton(onPressed: () {
                 Navigator.pop(ctx);
                 Navigator.pop(context); // Back to Login
              }, child: const Text('OK'))
            ],
         ));
       }
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
             const Text("Enter your email address to receive a password reset link."),
             const SizedBox(height: 20),
             TextField(
               controller: _emailController,
               decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
               ),
               keyboardType: TextInputType.emailAddress,
             ),
             const SizedBox(height: 24),
             SizedBox(
               width: double.infinity,
               child: FilledButton(
                 onPressed: _isLoading ? null : _resetPassword,
                 child: _isLoading ? const CircularProgressIndicator() : const Text("Send Reset Link"),
               ),
             )
          ],
        ),
      ),
    );
  }
}
