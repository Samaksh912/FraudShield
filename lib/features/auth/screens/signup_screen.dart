import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/brand_panel.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscure       = true;
  bool _loading       = false;
  String? _error;

  void _submit() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800));

    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() { _loading = false; _error = 'Please fill all fields.'; });
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() { _loading = false; _error = 'Passwords do not match.'; });
      return;
    }
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          Expanded(child: BrandPanel()),
          Container(
            width: 440,
            color: AppColors.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: _buildForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('FraudShield', style: AppTheme.sans(size: 18, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 32),
        Text('Create your account', style: AppTheme.sans(size: 22, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Start monitoring fraud in minutes',
            style: AppTheme.sans(size: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 32),

        _label('Email'),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: AppTheme.mono(size: 14),
          decoration: const InputDecoration(
            hintText: 'analyst@fraudshield.ai',
            prefixIcon: Icon(Icons.mail_outline, size: 18, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 16),

        _label('Password'),
        const SizedBox(height: 6),
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          style: AppTheme.mono(size: 14),
          decoration: InputDecoration(
            hintText: 'Min. 8 characters',
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18, color: AppColors.textMuted),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _label('Confirm Password'),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmCtrl,
          obscureText: true,
          style: AppTheme.mono(size: 14),
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '••••••••',
            prefixIcon: Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.fraudDim,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.fraud.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.fraud),
              const SizedBox(width: 8),
              Text(_error!, style: AppTheme.sans(size: 13, color: AppColors.fraud)),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Account'),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: GestureDetector(
            onTap: () => context.go('/login'),
            child: RichText(text: TextSpan(
              style: AppTheme.sans(size: 13, color: AppColors.textSecondary),
              children: [
                const TextSpan(text: 'Already have an account? '),
                TextSpan(text: 'Sign in',
                    style: AppTheme.sans(size: 13, color: AppColors.primary,
                        weight: FontWeight.w600)),
              ],
            )),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) =>
      Text(text, style: AppTheme.sans(size: 13, weight: FontWeight.w500,
          color: AppColors.textSecondary));
}