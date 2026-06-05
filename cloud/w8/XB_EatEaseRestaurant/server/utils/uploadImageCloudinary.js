import { v2 as cloudinary } from 'cloudinary';

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
})

const uploadImageCloudinary = async (image) => {
    try {
        const buffer = image?.buffer || Buffer.from(await image.arrayBuffer())

        const uploadImage = await new Promise((resolve, reject) => {
            cloudinary.uploader.upload_stream(
                {
                    folder: "eat_ease_restaurant",
                    resource_type: "auto"
                },
                (error, uploadResult) => {
                    if (error) {
                        reject(error)
                    } else {
                        resolve(uploadResult)
                    }
                }
            ).end(buffer)
        })

        return {
            success: true,
            data: {
                url: uploadImage.secure_url
            }
        }
    } catch (error) {
        console.error('Cloudinary upload error:', error)
        return {
            success: false,
            error: error.message || "Lỗi khi tải ảnh lên Cloudinary"
        }
    }
}

export default uploadImageCloudinary