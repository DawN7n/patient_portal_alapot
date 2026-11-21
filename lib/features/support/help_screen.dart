import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/ui.dart';

class HelpScreen extends StatelessWidget {
 const HelpScreen({super.key,required this.openChat}); final VoidCallback openChat;
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[
 const PageHeading('Help center',subtitle:'Find answers or talk with our clinic assistant.'),
 SurfaceCard(color:AppColors.sky,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Row(children:[CircleAvatar(backgroundColor:Colors.white,child:Icon(Icons.support_agent_rounded,color:AppColors.teal)),SizedBox(width:12),Expanded(child:Text('Talk to Alapot',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)))]),
 const SizedBox(height:7),const Text('Need help with appointments, services, clinic information or dental care questions? Start a conversation with our assistant.',style:TextStyle(fontSize:11,color:AppColors.muted,height:1.5)),
 const SizedBox(height:14),PrimaryButton(label:'Chat with Alapot',icon:Icons.chat_bubble_outline_rounded,onPressed:openChat),
 ])),
 const SizedBox(height:20),const SectionTitle('Frequently asked questions'),
 const SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 _Faq('How do I book an appointment?','Open Appointments or tap Book an appointment on the Home screen. Choose a service, dentist, date and time, then submit your request.'),
 _Faq('When is my appointment confirmed?','Your preferred schedule is a request until the clinic team reviews and approves it. You will receive a notification when its status changes.'),
 _Faq('Can I cancel an appointment?','Open Appointments and choose Request cancellation on a pending appointment.'),
 _Faq('Where can I see my dental history?','Open My Profile, then choose My records.'),
 _Faq('When can I leave a review?','You can review a dentist after the appointment has been marked as completed.'),
 ])),
 const SizedBox(height:16),const SectionTitle('Clinic assistance'),
 const SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('For urgent concerns or appointment changes, please contact clinic reception directly.',style:TextStyle(fontSize:11,color:AppColors.muted,height:1.5)),
 SizedBox(height:10),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.location_on_outlined,color:AppColors.teal),SizedBox(width:8),Expanded(child:Text('See Clinic information for address and hours',style:TextStyle(fontSize:11,fontWeight:FontWeight.w600)))])
 ]))
 ]);
}
class _Faq extends StatelessWidget {
 const _Faq(this.q,this.a); final String q,a;
 @override Widget build(BuildContext context)=>ExpansionTile(
 tilePadding:EdgeInsets.zero,childrenPadding:const EdgeInsets.only(bottom:12),
 title:Text(q,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
 children:[Text(a,style:const TextStyle(color:AppColors.muted,fontSize:11,height:1.5))]
 );
}
