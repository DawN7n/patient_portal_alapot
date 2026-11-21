import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class PageHeading extends StatelessWidget {
 const PageHeading(this.title,{super.key,this.subtitle,this.trailing});
 final String title; final String? subtitle; final Widget? trailing;
 @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:20),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.headlineMedium),if(subtitle!=null) ...[const SizedBox(height:4),Text(subtitle!,style:const TextStyle(color:AppColors.muted,fontSize:12))]])),if(trailing!=null)trailing!]));
}
class SurfaceCard extends StatelessWidget {
 const SurfaceCard({super.key,required this.child,this.padding=const EdgeInsets.all(18),this.color=Colors.white,this.onTap});
 final Widget child; final EdgeInsets padding; final Color color; final VoidCallback? onTap;
 @override Widget build(BuildContext context){final effectiveColor=color==Colors.white?Theme.of(context).cardColor:color;return Material(color:effectiveColor,borderRadius:BorderRadius.circular(22),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(22),child:Container(padding:padding,decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),border:Border.all(color:Theme.of(context).dividerColor.withValues(alpha: .8))),child:child)));}
}
class PrimaryButton extends StatelessWidget {
 const PrimaryButton({super.key,required this.label,required this.onPressed,this.icon});
 final String label; final VoidCallback onPressed; final IconData? icon;
 @override Widget build(BuildContext context)=>SizedBox(height:50,child:ElevatedButton(onPressed:onPressed,style:ElevatedButton.styleFrom(backgroundColor:AppColors.teal,foregroundColor:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),child:Row(mainAxisAlignment:MainAxisAlignment.center,mainAxisSize:MainAxisSize.min,children:[if(icon!=null) ...[Icon(icon,size:18),const SizedBox(width:7)],Text(label,style:const TextStyle(fontWeight:FontWeight.w600))])));
}
class SectionTitle extends StatelessWidget {
 const SectionTitle(this.title,{super.key,this.action,this.onTap});
 final String title; final String? action; final VoidCallback? onTap;
 @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12,top:8),child:Row(children:[Expanded(child:Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontSize:17,fontWeight:FontWeight.w700))),if(action!=null)TextButton(onPressed:onTap,child:Text(action!,style:const TextStyle(color:AppColors.teal,fontWeight:FontWeight.w600)))]));
}
class Avatar extends StatelessWidget {
 const Avatar({super.key,required this.initials,this.size=48,this.color=AppColors.sky});
 final String initials; final double size; final Color color;
 @override Widget build(BuildContext context)=>Container(width:size,height:size,alignment:Alignment.center,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(size*.34)),child:Text(initials,style:TextStyle(color:AppColors.deepTeal,fontWeight:FontWeight.w700,fontSize:size*.30)));
}
class StatusPill extends StatelessWidget {
 const StatusPill(this.label,{super.key,this.color=AppColors.gold});
 final String label; final Color color;
 @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:color.withValues(alpha: .13),borderRadius:BorderRadius.circular(30)),child:Text(label,style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w700)));
}
