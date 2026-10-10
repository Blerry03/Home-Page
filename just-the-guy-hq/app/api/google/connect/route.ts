import { NextRequest,NextResponse } from 'next/server';
import { authenticate,createState,googleReady,oauthUrl } from '../../../../lib/google-server';
export const runtime='nodejs';
export async function POST(req:NextRequest){
 try{if(!googleReady)return NextResponse.json({error:'Google integration is not configured yet. Follow GOOGLE-CALENDAR-SETUP.md.'},{status:503});const {user}=await authenticate(req);return NextResponse.json({url:oauthUrl(createState(user.id))});}
 catch(e){return NextResponse.json({error:e instanceof Error?e.message:'Connection failed'},{status:400});}
}
