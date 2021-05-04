/*
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */


#define Y(R,G,B) 0.299 * R + 0.587 * G + 0.114 * B
#define U(R,G,B) -0.147 * R - 0.289 * G + 0.436 * B
#define V(R,G,B) 0.615 * R - 0.515 * G - 0.100 * B
#define YUV(R,G,B) (float4)(Y(R,G,B),U(R,G,B),V(R,G,B),1)
#define GREY YUV(0.5,0.5,0.5)

#define PI 3.1415926535897932384626433832795

#define OVERLAP 64
#define CUT 688
#define BASESIZE 3968

//#define OLD 1
#ifdef OLD
__kernel void gopromax_stack(__write_only image2d_t dst,
                             __read_only  image2d_t gopromax_front,
                             __read_only  image2d_t gopromax_rear)
{
    const sampler_t sampler = (CLK_NORMALIZED_COORDS_FALSE |
                               CLK_ADDRESS_CLAMP_TO_EDGE   |
                               CLK_FILTER_NEAREST);

    float4 val;
    int2 loc = (int2)(get_global_id(0), get_global_id(1));
    int2 dst_size = get_image_dim(dst);
    int half_height = dst_size.y / 2;
    int cut0 = dst_size.x * CUT / BASESIZE;
    int cut1 = dst_size.x - cut0;
    int overlap = dst_size.x * OVERLAP / BASESIZE;

    int x;
    if (loc.x < (cut0-overlap))
    {
        x = loc.x;
    }
    else if ( (loc.x>=(cut0-overlap)) && ( loc.x < ( cut1 + overlap) ) )
    {
        x = loc.x + overlap;
    }
    else if ( loc.x >= ( cut1 - 2*overlap) )
    {
        x = loc.x + 2*overlap;
    }

    //cubemap layout
    // Left Front Right
    // Down Back Top
    if (loc.y < half_height)
    {
        val = read_imagef(gopromax_front, sampler, (int2)(x, loc.y));
        // We are in L.F.R. line
        if (loc.x < dst_size.x/3)
        {
            // In left
            //coordinates (0..dst_size.x/3 , 0..half_height)
        }
        else if ((loc.x >= dst_size.x/3) && (loc.x < 2*dst_size.x/3))
        {
            // In front
            //coordinates (dst_size.x/3..2*dst_size.x/3 , 0..half_h eight)
            
        }
        else
        {
            // In right
            //coordinates (2*dst_size.x/3..dst_size.x , 0..half_height)
        }
    }
    else
    {
        val = read_imagef(gopromax_rear, sampler, (int2)(x, loc.y-half_height));
        //We are in D.B.T. line
        if (loc.x < dst_size.x/3)
        {
            // In down
            //coordinates (0..dst_size.x/3 , half_height..dst_size.y)
        }
        else if ((loc.x >= dst_size.x/3) && (loc.x < 2*dst_size.x/3))
        {
            // In back
            //coordinates (dst_size.x/3..2*dst_size.x/3 , half_height..dst_size.y)

        }
        else
        {
            // In top
            //coordinates (2*dst_size.x/3..dst_size.x , 0..half_height)
            
        }
    }

    write_imagef(dst, loc, val);
}
#else
float2 get_spherical_coordinates(int2 xy, int2 size);
float3 get_cartesian_coordinates(float2 phi_theta);

float2 get_spherical_coordinates(int2 xy, int2 size)
{

    
    float phi =  (1.0-2.0*((float)xy.y/(float)size.y))/2.0 * PI;
    
    float theta = (2.0*((float)xy.x/(float)size.x)-1.0) * PI;
    return (float2)(phi,theta);
    
}

float3 get_cartesian_coordinates(float2 phi_theta)
{
    float x = cos(phi_theta.x) * cos(phi_theta.y);
    float y = sin(phi_theta.x);
    float z = cos(phi_theta.x) * sin(phi_theta.y);
    return (float3)(x,y,z);
}

const sampler_t sampler = (CLK_NORMALIZED_COORDS_FALSE |
                           CLK_ADDRESS_CLAMP_TO_EDGE   |
                           CLK_FILTER_NEAREST);

int2 normalize_face_coordinates(float2 uv, int face_size)
{
        float2 xy;
        xy.x= 0.5*(uv.x+1)*face_size;
        xy.y= 0.5*(uv.y+1)*face_size;
        return (int2)( (int)(xy.x), (int)(xy.y) );
}

float4 get_val_at_src_local_coordinates(float3 xyz, __read_only  image2d_t front, __read_only  image2d_t rear)
{
    float2 uv_normalized;
    int2 uv;
    int2 dim = get_image_dim(front);
    int face_size = dim.y;
    float4 val;
    if (xyz.x>0)
        {//Front
            uv_normalized.x = -xyz.z;
            uv_normalized.y = xyz.y;
            uv = normalize_face_coordinates(uv_normalized,face_size);
            uv.x = (uv.x+face_size);
            uv.y = (uv.y);

        }
    if (xyz.x<0)
        {//Back
            //uv_normalized.x = xyz.z;
            //uv_normalized.y = xyz.y;
            //rotate +90°
            uv_normalized.x = xyz.y;
            uv_normalized.y = -xyz.z;
            uv = normalize_face_coordinates(uv_normalized,face_size);
            uv.x = (uv.x+face_size);
            uv.y = (uv.y+face_size);
        }
    if (xyz.y>0)
        {//Top
            //uv_normalized.x = (xyz.x);
            //uv_normalized.y = (-xyz.z);
            //rotate -90°
            uv_normalized.x = (xyz.z);
            uv_normalized.y = (xyz.x);
            uv = normalize_face_coordinates(uv_normalized,face_size);
            uv.x = (uv.x+2*face_size);
            uv.y = (uv.y+face_size);
        }
    if (xyz.y<0)
        {//Down
            //uv_normalized.x = (xyz.x);
            //uv_normalized.y = (xyz.z);
            //rotate -90°
            uv_normalized.x = (-xyz.z);
            uv_normalized.y = (xyz.x);
            uv = normalize_face_coordinates(uv_normalized,face_size);
            uv.x = (uv.x);
            uv.y = (uv.y+face_size);
        }
    if (xyz.z>0)
        {//Right
            uv_normalized.x = (xyz.x);
            uv_normalized.y = (xyz.y);
            uv = normalize_face_coordinates(uv_normalized,face_size);
            uv.x = (uv.x+2*face_size);
            uv.y = (uv.y+face_size);
        }
    if (xyz.z<0)
        {//Left
            uv_normalized.x = (-xyz.x);
            uv_normalized.y = (xyz.y);
            uv = normalize_face_coordinates(uv_normalized,face_size);
            uv.x = (uv.x);
            uv.y = (uv.y);
        }
    if (uv.y<face_size)
        val = read_imagef(front, sampler, uv);
    else
        val = read_imagef(rear, sampler, int2(uv.x,uv.y-face_size));
    return val;
}

__kernel void gopromax_stack(__write_only image2d_t dst,
                             __read_only  image2d_t gopromax_front,
                             __read_only  image2d_t gopromax_rear)
{
    
    float4 val;
    int2 loc = (int2)(get_global_id(0), get_global_id(1));

    int2 dst_size = get_image_dim(dst);
    int2 src_size = get_image_dim(gopromax_front);
    
    float2 phi_theta = get_spherical_coordinates(loc,dst_size);
    float3 xyz = get_cartesian_coordinates(phi_theta);
    val = get_val_at_src_local_coordinates(xyz,gopromax_front, gopromax_rear);

    write_imagef(dst, loc, val);

}
#endif
