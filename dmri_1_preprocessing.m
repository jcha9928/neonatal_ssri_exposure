function dmri_1_preprocessing(order)

%% reset LD_LIBRARY_PATH
LD_LIBRARY_PATH=['/nfs/apps/gcc/4.9.2/lib64'];
%/home/juke/MATLAB/R2016b/sys/os/glnxa64:

setenv('LD_LIBRARY_PATH', LD_LIBRARY_PATH)
!echo $LD_LIBRARY_PATH

parentdir='/ifs/scratch/pimri/posnerlab/1anal/Monk/data';

[num,txt,raw] = xlsread(fullfile(parentdir,'list_good_dwi.xls'));

disp(['NOW PROCESSING ORDER ' int2str(order)])
s=num(order+1,2)
setenv('s', int2str(s))
workingdir=fullfile(parentdir,int2str(s));
cd(workingdir)


%% 1. setup %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cd('DTI')
dwiname=txt(order+1,3)
cmd=['find . -maxdepth 1 -name "' dwiname{1} '"'] 
[status, out]=system(cmd)

% if status==1, error('NO RAW DWI FILES WERE FOUND'), end

img_dwi=out(1:length(out)-1)


C=regexp(dwiname{1},'[.]','split')
img_bvecs=fullfile(pwd,[C{1} '.bvec'])
img_bvals=fullfile(pwd,[C{1} '.bval'])


  if ~exist('mr_fod.mif')
%% 2. DWI processing2-converting nifti to mif%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cmd = (['mrconvert ' img_dwi ' -force mr_dwi.mif -fslgrad ' img_bvecs ' ' img_bvals ' -datatype float32 -stride 0,0,0,1'])
unix(cmd)

%% denoising
cmd = (['dwidenoise mr_dwi.mif -force mr_dwi_denoised.mif -nthreads 4']);
unix(cmd)

%% dwipreproc -eddy current
cmd = (['dwipreproc PA mr_dwi_denoised.mif mr_dwi_denoised_preproc.mif -rpe_none -force'])
unix(cmd)

%% mask and bias field correction
% img_dwi_biasCorr=fullfile(workingdir,'dwi_denoised_biasCorr.nii.gz');
unix(['dwi2mask mr_dwi_denoised_preproc.mif - | maskfilter - erode -npass 7 -force mr_eroded_mask.mif'])

cmd = (['dwibiascorrect mr_dwi_denoised_preproc.mif -force mr_dwi_denoised_preproc_biasCorr.mif -ants -mask mr_eroded_mask.mif -fslgrad ' img_bvecs ' ' img_bvals ' -nthreads 4']);
unix(cmd) 


%% DWI processing3- bad vol exclusion %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% if stripe noise is found in a volume, make sure you delete %%%%
range=txt(order+1,6)

cmd=['mrconvert -coord 3 ' range{1} ' mr_dwi_denoised_preproc_biasCorr.mif -force mr_dwi_denoised_preproc_biasCorr_reduced.mif']
unix(cmd)


%%%% generating b0 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
unix('dwiextract mr_dwi_denoised_preproc_biasCorr_reduced.mif - -bzero | mrmath - mean -force mr_meanb0.mif -axis 3')

%% upsampling %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
filelist={'mr_dwi_denoised_preproc_biasCorr_reduced','mr_eroded_mask','mr_meanb0'};
for i=1:length(filelist)
    im=[filelist{i} '.mif'];
    newim=[filelist{i} '_upsample.mif'];
    cmd=['mrresize ' im ' -scale 2.0 -force ' newim];
    unix(cmd)
end


%%%% eroded mask

cmd=['dwi2mask mr_dwi_denoised_reduced.mif - | maskfilter - erode -npass 7 mr_eroded_mask.mif -force']
unix(cmd)

%%%% response
cmd=['dwi2response tournier -mask mr_eroded_mask.mif -voxels mr_voxels_reduced_eroded.mif mr_dwi_denoised_preproc_biasCorr_reduced.mif mr_dwi_response_tournier_reduced_eroded.txt -force'];
unix(cmd)

%% global intensity normalization  THIS MIGHT BE SKIPPED


%% FOD%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% make sure to use "DILATED MASK" for FOD generation
unix(['dwi2mask mr_dwi_denoised_preproc_biasCorr_reduced.mif - | maskfilter - dilate -npass 5 -force mr_dilate_mask.mif'])
% unix(['mrresize mr_dilate_mask.mif -scale 2.0 mr_dilate_mask_upsample.mif'])

cmd1=['dwi2fod csd mr_dwi_denoised_preproc_biasCorr_reduced.mif mr_dwi_response_tournier_reduced_eroded.txt mr_fod.mif -mask mr_dilate_mask.mif -nthreads 4 -force'];
unix(cmd1)

disp('I THINK EVERYTHING IS DONE BY NOW')
end


end
