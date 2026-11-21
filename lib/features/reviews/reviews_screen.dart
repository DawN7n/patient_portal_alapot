import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../shared/widgets/ui.dart';

class ReviewsScreen extends StatefulWidget { const ReviewsScreen({super.key}); @override State<ReviewsScreen> createState()=>_ReviewsScreenState(); }
class _ReviewsScreenState extends State<ReviewsScreen> {
  final _repo=PatientPortalRepository();
  bool _busy=false;
  Future<void> _review(Map<String,dynamic> a) async {
    var rating=5; var showName=false; final comment=TextEditingController();
    final result=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:const Text('Share your feedback'),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Your rating',style:TextStyle(fontWeight:FontWeight.w700)),
        Row(children:List.generate(5,(i)=>IconButton(onPressed:()=>setDialog(()=>rating=i+1),icon:Icon(i<rating?Icons.star:Icons.star_border,color:AppColors.gold)))),
        TextField(controller:comment,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'Comment (optional)')),
        CheckboxListTile(value:showName,onChanged:(v)=>setDialog(()=>showName=v??false),contentPadding:EdgeInsets.zero,title:const Text('Show my name with this review',style:TextStyle(fontSize:11))),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Submit review'))],
    )));
    if(result!=true)return;
    setState(()=>_busy=true);
    try { await _repo.submitReview(appointmentId:(a['_docId']??a['id']).toString(),dentistUid:(a['dentist_id']??'').toString(),dentistName:(a['dentist']??'').toString(),rating:rating,comment:comment.text,showName:showName); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Your review was submitted for clinic review.'))); }
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Review could not be submitted: $e')));}
    finally{comment.dispose();if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>StreamBuilder<List<Map<String,dynamic>>>(stream:_repo.watchMyAppointments(),builder:(context,appts){
    final completed=[...?appts.data].where((a)=>(a['status']??'').toString().toLowerCase()=='completed').toList();
    return StreamBuilder<List<Map<String,dynamic>>>(stream:_repo.watchMyReviews(),builder:(context,reviews){
      final byAppointment=<String,Map<String,dynamic>>{};for(final r in reviews.data??const []){byAppointment[(r['appointment_id']??'').toString()]=r;}
      return ListView(padding:const EdgeInsets.all(22),children:[
        const PageHeading('My reviews',subtitle:'Review completed visits and see the feedback you have already submitted.'),
        if(appts.hasError||reviews.hasError) SurfaceCard(child:Text('Reviews could not be loaded: ${appts.error??reviews.error}'))
        else if(!appts.hasData||!reviews.hasData) const Center(child:CircularProgressIndicator())
        else if(completed.isEmpty) const SurfaceCard(child:Text('Completed appointments will appear here when the clinic marks a visit as completed.',style:TextStyle(color:AppColors.muted,fontSize:11)))
        else ...completed.map((a){final id=(a['_docId']??a['id']??'').toString();final review=byAppointment[id];return Padding(padding:const EdgeInsets.only(bottom:11),child:SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text((a['service']??'Dental appointment').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:4),Text('${a['dentist']??'Dentist'} · ${a['date']??''}',style:const TextStyle(fontSize:10,color:AppColors.muted)),
          const SizedBox(height:9),
          if(review!=null)...[Text('★'*(((review['rating'] as num?)?.toInt()??0).clamp(0,5)),style:const TextStyle(color:AppColors.gold,letterSpacing:2)),if((review['comment']??'').toString().isNotEmpty)Text(review['comment'].toString(),style:const TextStyle(fontSize:11)),const StatusPill('SUBMITTED',color:AppColors.green)]
          else Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:_busy?null:()=>_review(a),icon:const Icon(Icons.rate_review_outlined),label:const Text('Write a review'))),
        ])));}),
        if(_busy)const LinearProgressIndicator(),
      ]);
    });
  });
}
