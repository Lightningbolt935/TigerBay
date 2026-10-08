import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/features/home/widgets/venue_dashboard_card.dart';

const String _kConciergeEmail = 'bookings@tigerbayshisha.co.uk';

/// Opens the Contact Us & Direct Enquiry Modal from anywhere in the app
Future<void> showContactUsModal(
  BuildContext context, {
  Branch? initialVenue,
  String? initialPackage,
  String? initialEnquiryType,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF141416),
    barrierColor: Colors.black.withValues(alpha: 0.8),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: ContactUsForm(
          initialVenue: initialVenue,
          initialPackage: initialPackage,
          initialEnquiryType: initialEnquiryType,
          isModal: true,
        ),
      ),
    ),
  );
}

/// Standalone screen for `/contact-us` route
class ContactUsScreen extends StatelessWidget {
  final Branch? initialVenue;
  final String? initialPackage;

  const ContactUsScreen({
    super.key,
    this.initialVenue,
    this.initialPackage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141416),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Contact & Enquiries',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: ContactUsForm(
        initialVenue: initialVenue,
        initialPackage: initialPackage,
        isModal: false,
      ),
    );
  }
}

class ContactUsForm extends ConsumerStatefulWidget {
  final Branch? initialVenue;
  final String? initialPackage;
  final String? initialEnquiryType;
  final bool isModal;

  const ContactUsForm({
    super.key,
    this.initialVenue,
    this.initialPackage,
    this.initialEnquiryType,
    required this.isModal,
  });

  @override
  ConsumerState<ContactUsForm> createState() => _ContactUsFormState();
}

class _ContactUsFormState extends ConsumerState<ContactUsForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _guestsController;
  late TextEditingController _dateController;
  late TextEditingController _messageController;

  Branch? _selectedBranch;
  String _selectedEnquiryType = 'Table Reservation';
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  final List<String> _enquiryTypes = [
    'Table Reservation',
    'VIP Lounge Package',
    'Birthday & Celebration',
    'Private Venue Hire',
    'Corporate Booking',
    'Shisha Inquiry',
    'General Enquiry',
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);

    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _guestsController = TextEditingController(text: '4');
    _dateController = TextEditingController();

    if (widget.initialPackage != null) {
      _selectedEnquiryType = 'VIP Lounge Package';
      _messageController = TextEditingController(
        text: 'Inquiry for package: "${widget.initialPackage}". Please advise availability and booth options.',
      );
    } else {
      _selectedEnquiryType = widget.initialEnquiryType ?? 'Table Reservation';
      _messageController = TextEditingController();
    }

    _selectedBranch = widget.initialVenue ?? ref.read(selectedBranchProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _guestsController.dispose();
    _dateController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _submitEnquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final venueName = _selectedBranch?.title ?? 'Tiger Bay General';
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final guests = _guestsController.text.trim();
    final dateStr = _dateController.text.trim();
    final message = _messageController.text.trim();

    // 1. Record enquiry directly to Supabase public.enquiries table
    try {
      final fullMessage = StringBuffer(message);
      if (guests.isNotEmpty) fullMessage.write('\nGuests: $guests');
      if (dateStr.isNotEmpty) fullMessage.write('\nPreferred Date: $dateStr');

      await Supabase.instance.client.from('enquiries').insert({
        if (_selectedBranch?.id != null) 'branch_id': _selectedBranch!.id,
        'customer_name': name,
        'customer_email': email,
        'customer_phone': phone.isNotEmpty ? phone : null,
        'subject': _selectedEnquiryType,
        'message': fullMessage.toString(),
        'recipient_email': _kConciergeEmail,
        'status': 'pending',
      });
    } catch (_) {
      // Continue with email dispatch
    }

    // 2. Prepare mailto URI to bookings@tigerbayshisha.co.uk
    final subject = Uri.encodeComponent(
      'Tiger Bay Enquiry: $_selectedEnquiryType — $venueName ($name)',
    );
    final body = Uri.encodeComponent(
      'New Customer Enquiry Submitted via Tiger Bay International App:\n\n'
      '--------------------------------------------------\n'
      '• Venue Branch: $venueName\n'
      '• Enquiry Type: $_selectedEnquiryType\n'
      '• Customer Name: $name\n'
      '• Email Address: $email\n'
      '• Phone Number: $phone\n'
      '• Target Date: ${dateStr.isNotEmpty ? dateStr : "To be confirmed"}\n'
      '• Number of Guests: $guests\n'
      '--------------------------------------------------\n\n'
      'Customer Message / Special Requirements:\n'
      '$message\n\n'
      'Sent from Tiger Bay International Mobile App.',
    );

    final mailtoUri = Uri.parse('mailto:$_kConciergeEmail?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // 3. Show Success Confirmation Dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18191E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF34C759),
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enquiry Submitted!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your enquiry has been dispatched directly to our reservations team at:',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: SelectableText(
                _kConciergeEmail,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A VIP booking coordinator for $venueName will contact you shortly to confirm your reservation and arrange booth details.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textHint,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          // WhatsApp Follow-up Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366), width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 16),
              label: Text(
                'CHAT ON WHATSAPP (+44 7598 819733)',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: () {
                final targetVenue = _selectedBranch ?? Branch.kingsbury;
                launchVenueWhatsApp(context, targetVenue);
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (widget.isModal) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              child: Text(
                'DONE',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final branches = branchesAsync.valueOrNull ?? Branch.defaultBranches;

    if (_selectedBranch == null && branches.isNotEmpty) {
      _selectedBranch = branches.first;
    }

    return Column(
      children: [
        if (widget.isModal) ...[
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mark_email_unread_rounded,
                        color: AppColors.gold, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Contact Us & Enquiries',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textHint),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
        ],
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Destination Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mail_outline_rounded,
                            color: AppColors.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Direct Concierge Dispatch',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'All submissions send directly to $_kConciergeEmail',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Instant WhatsApp Chat Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant WhatsApp Support',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Direct enquiry via WhatsApp concierge',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final targetVenue = _selectedBranch ??
                                (branches.isNotEmpty ? branches.first : Branch.kingsbury);
                            launchVenueWhatsApp(context, targetVenue);
                          },
                          child: Text(
                            'CHAT NOW',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1. Venue Selection
                  _buildSectionLabel('SELECT VENUE BRANCH'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder, width: 0.8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Branch>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1C1C1E),
                        value: _selectedBranch,
                        items: branches.map((b) {
                          return DropdownMenuItem<Branch>(
                            value: b,
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded,
                                    color: AppColors.gold, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Tiger Bay ${b.title}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (b) => setState(() => _selectedBranch = b),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Enquiry Type
                  _buildSectionLabel('ENQUIRY TYPE'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder, width: 0.8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1C1C1E),
                        value: _selectedEnquiryType,
                        items: _enquiryTypes.map((t) {
                          return DropdownMenuItem<String>(
                            value: t,
                            child: Text(
                              t,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (t) {
                          if (t != null) setState(() => _selectedEnquiryType = t);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Name & Phone Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('YOUR FULL NAME'),
                            _buildTextField(
                              controller: _nameController,
                              hint: 'e.g. James Smith',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('PHONE NUMBER'),
                            _buildTextField(
                              controller: _phoneController,
                              hint: '+44 7...',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Email Address
                  _buildSectionLabel('EMAIL ADDRESS'),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Invalid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 5. Target Date & Guests Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('PREFERRED DATE'),
                            GestureDetector(
                              onTap: _pickDate,
                              child: AbsorbPointer(
                                child: _buildTextField(
                                  controller: _dateController,
                                  hint: 'Select Date',
                                  prefixIcon: Icons.calendar_today_rounded,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('NUMBER OF GUESTS'),
                            _buildTextField(
                              controller: _guestsController,
                              hint: '4',
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.group_outlined,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 6. Message / Special Requests
                  _buildSectionLabel('MESSAGE & SPECIAL REQUESTS'),
                  _buildTextField(
                    controller: _messageController,
                    hint: 'Tell us about your occasion, preferred seating (booth/outdoor heated terrace), or shisha requirements...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            AppColors.gold.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _submitEnquiry,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded,
                                    size: 18, color: Colors.black),
                                const SizedBox(width: 8),
                                Text(
                                  'SEND ENQUIRY',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: AppColors.textHint,
          fontSize: 13,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.gold, size: 18)
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
      ),
    );
  }
}
