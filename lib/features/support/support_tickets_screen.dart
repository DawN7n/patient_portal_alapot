import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../shared/widgets/ui.dart';

/// Patient view of saved Alapot AI conversations and any replies from clinic staff.
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key, this.onContinueWithAi});
  final ValueChanged<Map<String, dynamic>>? onContinueWithAi;
  @override State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}
class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _repo=PatientPortalRepository();
  String? _selectedId;
  bool _mobileChatOpen=false;
  @override Widget build(BuildContext context)=>StreamBuilder<List<Map<String,dynamic>>>(
    stream:_repo.watchMySupportTickets(),builder:(context,snapshot){
      final tickets=[...?snapshot.data]..sort((a,b)=>(b['updatedAt']??'').toString().compareTo((a['updatedAt']??'').toString()));
      Map<String,dynamic>? selected;
      for(final ticket in tickets){if((ticket['_docId']??ticket['id'])==_selectedId)selected=ticket;}
      selected??=tickets.isNotEmpty?tickets.first:null;
      final id=(selected?['_docId']??selected?['id']??'').toString();
      if(_selectedId==null&&id.isNotEmpty){WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&_selectedId==null)setState(()=>_selectedId=id);});}
      return LayoutBuilder(builder:(context,c){final mobile=c.maxWidth<760;return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const PageHeading('My Tickets',subtitle:'Review saved Alapot AI conversations and clinic replies.'),
        if(snapshot.hasError) SurfaceCard(child:Text('Could not load your tickets: ${snapshot.error}'))
        else if(!snapshot.hasData) const Expanded(child:Center(child:CircularProgressIndicator()))
        else if(tickets.isEmpty) const Expanded(child:Center(child:Text('No saved tickets yet. Start a conversation with Alapot AI and choose Save to My Tickets.')))
        else Expanded(child:mobile
          ? (_mobileChatOpen && selected!=null
              ? Column(children:[_mobileHeader(selected),Expanded(child:_chat(selected))])
              : _ticketList(tickets,id))
          : Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              SizedBox(width:300,child:_ticketList(tickets,id)),
              const SizedBox(width:12),
              Expanded(child:selected==null?_empty():Column(children:[_ticketHeader(selected),Expanded(child:_chat(selected))]))
            ]))
      ]);});
    });
  Widget _ticketList(List<Map<String,dynamic>> tickets,String selectedId)=>SurfaceCard(padding:EdgeInsets.zero,child:ListView.separated(
    itemCount:tickets.length,
    separatorBuilder:(_,__)=>const Divider(height:1),
    itemBuilder:(context,index){
      final ticket=tickets[index];
      final ticketId=(ticket['_docId']??ticket['id']??'').toString();
      return ListTile(
        selected:ticketId==selectedId,
        title:Text((ticket['subject']??'Alapot AI conversation').toString(),maxLines:1,overflow:TextOverflow.ellipsis),
        subtitle:Text('${ticket['category']??'Inquiry'} · ${(ticket['status']??'waiting').toString().replaceAll('_',' ')}'),
        trailing:const Icon(Icons.chevron_right),
        onTap:()=>setState(() { _selectedId=ticketId; _mobileChatOpen=MediaQuery.of(context).size.width<760; }),
      );
    },
  ));
  Widget _mobileHeader(Map<String,dynamic> ticket)=>Padding(
    padding:const EdgeInsets.only(bottom:8),
    child:Row(children:[
      IconButton(onPressed:()=>setState(()=>_mobileChatOpen=false),icon:const Icon(Icons.arrow_back),tooltip:'Back to My Tickets'),
      Expanded(child:_ticketHeader(ticket)),
    ]),
  );
  Widget _ticketHeader(Map<String,dynamic> t)=>SurfaceCard(child:Row(children:[const Icon(Icons.forum_outlined,color:AppColors.teal),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((t['subject']??'Alapot AI conversation').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),Text('Ticket ${(t['id']??t['_docId']??'').toString()} · ${(t['status']??'waiting').toString().replaceAll('_',' ')}',style:const TextStyle(color:AppColors.muted,fontSize:12))])),if(widget.onContinueWithAi!=null && (t['status']??'').toString().toLowerCase()!='resolved') IconButton.filledTonal(onPressed:()=>widget.onContinueWithAi!(t),icon:const Icon(Icons.smart_toy_outlined),tooltip:'Continue with Alapot AI')]));
  Widget _chat(Map<String,dynamic> t){final messages=(t['messages'] as List<dynamic>? ?? const []);return SurfaceCard(padding:const EdgeInsets.all(12),child:ListView.builder(itemCount:messages.length,itemBuilder:(context,index){final m=Map<String,dynamic>.from(messages[index] as Map);final own=(m['sender_role']??m['sender'])=='patient';final date=DateTime.tryParse((m['createdAt']??'').toString());return Align(alignment:own?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:const BoxConstraints(maxWidth:520),margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:own?AppColors.teal.withValues(alpha:.12):Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((m['name']??(own?'You':'Alapot AI / Clinic')).toString(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text((m['text']??'').toString()),if(date!=null)Text(DateFormat('MMM d · h:mm a').format(date.toLocal()),style:const TextStyle(fontSize:10,color:AppColors.muted))]))); }));}
  Widget _empty()=>const SurfaceCard(child:Center(child:Text('Select a ticket to review the conversation.')));
}
