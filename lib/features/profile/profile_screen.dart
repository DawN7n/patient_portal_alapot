import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/ui.dart';

class ProfileScreen extends StatelessWidget {
 const ProfileScreen({super.key,required this.name,required this.openPatientProfile,required this.openRecords,required this.openReviews,required this.openSettings,required this.openPayments,required this.logout});
 final String name; final VoidCallback openPatientProfile,openRecords,openReviews,openSettings,openPayments,logout;
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[
  const PageHeading('Settings',subtitle:'Manage your account and preferences.'),
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppColors.teal,AppColors.deepTeal]),borderRadius:BorderRadius.circular(22)),child:Row(children:[
   CircleAvatar(radius:30,backgroundColor:Colors.white,child:Text(name.trim().isEmpty?'P':name.trim().split(' ').map((x)=>x[0]).take(2).join().toUpperCase(),style:const TextStyle(color:AppColors.teal,fontWeight:FontWeight.w800,fontSize:18))),
   const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:16)),const Text('Patient account',style:TextStyle(color:Colors.white70,fontSize:11)),const SizedBox(height:4),const Text('Manage your personal account',style:TextStyle(color:Colors.white,fontSize:10))]))
  ])),
  const SizedBox(height:18),const SectionTitle('Account'),
  _tile(Icons.person_outline,'Patient profile','View your personal and patient information',openPatientProfile),
  _tile(Icons.folder_shared_outlined,'My records','Dental chart, visit history, consultation notes and files',openRecords),
  _tile(Icons.star_outline_rounded,'My reviews','Reviews you have submitted',openReviews),
  _tile(Icons.account_balance_wallet_outlined,'Manage payments','View payment history and official clinic receipts',openPayments),
  _tile(Icons.lock_outline,'Password & security','Change your password and review privacy information',openSettings),
  const SizedBox(height:8),_tile(Icons.logout_rounded,'Log out','Sign out of this device',logout,color:AppColors.red),
 ]);
 Widget _tile(IconData icon,String title,String sub,VoidCallback tap,{Color color=AppColors.teal})=>Padding(padding:const EdgeInsets.only(bottom:9),child:SurfaceCard(onTap:tap,padding:const EdgeInsets.symmetric(horizontal:15,vertical:14),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha: .10),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:color)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)),Text(sub,style:const TextStyle(color:AppColors.muted,fontSize:10))])),const Icon(Icons.chevron_right,color:AppColors.muted)])));
}
