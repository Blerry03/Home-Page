import { NextRequest,NextResponse } from 'next/server';
import {authenticate,googleReady} from '../../../../lib/google-server';
export const runtime='nodejs';
export async function POST(req:NextRequest){
 try{if(!googleReady)return NextResponse.json({connected:false});const {db,user}=await authenticate(req);const {data,error}=await db.from('google_calendar_connections').select('user_id').eq('user_id',user.id).maybeSingle();if(error)throw Error(error.message);return NextResponse.json({connected:Boolean(data)});}
 catch(e){return NextResponse.json({error:e instanceof Error?e.message:'Status failed'},{status:400});}
}
