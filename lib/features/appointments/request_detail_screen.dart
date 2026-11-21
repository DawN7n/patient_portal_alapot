import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/ui.dart';
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.onAppointments});
  final VoidCallback onAppointments;
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(22),children:[
    const PageHeading('Appointment request',subtitle:'Your booking request was sent to Alapot Dental Clinic.'),
    const SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(Icons.check_circle_outline,color:AppColors.green,size:28),SizedBox(width:10),Expanded(child:Text('Request submitted',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)))]),
      SizedBox(height:12),Text('The clinic will review the request and update its status in your Appointments and Notifications. A booking is not confirmed until the clinic approves it.',style:TextStyle(fontSize:12,height:1.55,color:AppColors.muted)),
    ])),
    const SizedBox(height:16),PrimaryButton(label:'View appointments',onPressed:onAppointments),
  ]);
}
