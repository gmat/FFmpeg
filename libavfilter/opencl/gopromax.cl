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
#define YUV(R,G,B) (float4)(Y(R,G,B),U(R,G,B),V(R,G,B),0)

__kernel void gopromax_stack(__write_only image2d_t dst,
                                __read_only  image2d_t gopromax_front,
                                __read_only  image2d_t gopromax_rear)
{
    const sampler_t sampler = (CLK_NORMALIZED_COORDS_FALSE |
                               CLK_FILTER_NEAREST);
    
    float4 val;
    int2 dst_size = get_image_dim(dst);
    int2 loc = (int2)(get_global_id(0), get_global_id(1));
    int split_loc = dst_size.y/2;

        if (loc.y < split_loc)
        {
            val = read_imagef(gopromax_front, sampler, (int2)(loc.x, loc.y));
            //val = YUV(0.5f,0.5f,0.5f);
        }
        else
        {
            
            val = read_imagef(gopromax_rear, sampler, (int2)(loc.x, loc.y-split_loc));
            //val = YUV(0,0,0);
        }

    if ((loc.x<dst_size.x) && (loc.y<dst_size.y))
        write_imagef(dst, loc, val);
}
