import firebase_admin
from firebase_admin import credentials
from firebase_admin import storage
from moviepy.editor import VideoFileClip, concatenate_videoclips
import subprocess
import os
import ffmpeg
import time

def concatenate_videos(input_dir, output_file):
    input_files = [f for f in os.listdir(input_dir) if f.endswith('.mov')]
    input_files.sort()

    input_streams = []
    for file in input_files:
        input_streams.append(ffmpeg.input(os.path.join(input_dir, file)))

    # Concatenate the input streams
    ffmpeg.concat(*input_streams, v=1).output(output_file).run()

def loop(blobs):

    # Date Format
    #2024 02 17 14 06 53
    #YYYY MM DD HH MM SS

    # Iterate over the blobs and print their names
    most_recent_dir = 0
    blobs = [blob for blob in blobs if len(blob.name) == 62]
    for blob in blobs:
        name_to_int = int(blob.name[7:21])
        most_recent_dir = max(most_recent_dir, name_to_int)

    most_recent_dir_str = str(most_recent_dir)

    print("\nMost recent directory:", most_recent_dir_str)

    # Download all videos from the most recent directory
    video_dir = os.path.join('data', 'nerf', most_recent_dir_str)
    os.makedirs(video_dir, exist_ok=True)

    for blob in blobs:
        if most_recent_dir_str in blob.name:
            blob.download_to_filename(os.path.join(video_dir, blob.name.split('/')[-1]))

    print(video_dir)

    # List all `.mov` files in the directory
    mov_files = [f for f in os.listdir(video_dir) if (f.endswith('.mov') or f.endswith('.MOV'))]

    # Create a list of VideoFileClip objects from the `.mov` files
    video_clips = [VideoFileClip(os.path.join(video_dir, f)) for f in mov_files]

    video_clips = [clip.rotate(90) for clip in video_clips]

    # Get the first clip's aspect ratio
    aspect_ratio = video_clips[0].size
    print("ASPECT RATIO: ", aspect_ratio)

    # Concatenate video clips
    final_clip = concatenate_videoclips(video_clips, method="compose")

    # Save the final concatenated video with the same resolution as the input clips
    final_clip.write_videofile(os.path.join(video_dir, 'render_this_video.mp4'), codec="libx264")

    # Close the video clips
    for clip in video_clips:
        clip.close()

    print("\nVideos stitched together and saved as 'render_this_video.mp4'")

    # Change the current working directory to data/nerf/most_recent_dir
    os.chdir(video_dir)

    file_name = "render_this_video.mp4"

    # Construct the command
    command = f'C:/Users/alexa/AppData/Local/Programs/Python/Python310/python.exe ..\..\..\scripts\colmap2nerf.py --video_in {file_name} --video_fps 10 --run_colmap --aabb_scale 16 --overwrite'
    subprocess.run(command, shell=True)

    os.chdir(original_dir)

    command = f'.\instant-ngp.exe .\{video_dir}'
    subprocess.run(command, shell=True)


# Initialize Firebase Admin SDK
cred = credentials.Certificate("dreal-f452e-firebase-adminsdk-fjhqq-685204e048.json")
firebase_admin.initialize_app(cred)

# Get a reference to the Firebase Storage service
storage_client = storage

original_dir = os.getcwd()

# List all objects in the videos folder
blobs = storage_client.bucket('dreal-f452e.appspot.com').list_blobs(prefix='videos/')
blobs = [blob for blob in blobs]

while True:
    # Check if there is a new directory every 10 minutes
    curr_blobs = storage_client.bucket('dreal-f452e.appspot.com').list_blobs(prefix='videos/')
    curr_blobs = [blob for blob in curr_blobs]
    print("check", len(curr_blobs), len(blobs))
    if len(curr_blobs) > len(blobs):
        loop(storage_client.bucket('dreal-f452e.appspot.com').list_blobs(prefix='videos/'))

    # Sleep for 10 seconds before checking again
    print("wait")
    blobs = storage_client.bucket('dreal-f452e.appspot.com').list_blobs(prefix='videos/')
    blobs = [blob for blob in blobs]
    time.sleep(5)